const std = @import("std");

/// Allocate a voice for a new note on `channel`.
///
/// Preference order:
///   1. The voice previously used by this channel, if it is now inactive.
///   2. The first inactive voice.
///   3. Steal: the quietest voice already in its release stage.
///   4. Steal: the quietest voice overall (by envelope value).
///
/// When a voice is stolen, any stale channel mapping pointing at it is
/// cleared so the previous owner no longer routes through it.
pub fn allocateVoice(voices: []Voice, channel_voices: *[8]?usize, channel: usize) ?usize {
    if (voices.len == 0) return null;

    // 1. Reuse this channel's previous voice if it is free
    if (channel < 8) {
        if (channel_voices[channel]) |cv| {
            if (cv < voices.len and !voices[cv].active) {
                return cv;
            }
        }
    }

    // 2. First free voice
    for (voices, 0..) |*voice, i| {
        if (!voice.active) return i;
    }

    // 3/4. Steal the quietest voice, preferring ones already releasing
    var steal_idx: ?usize = null;
    var steal_env: f32 = std.math.inf(f32);
    for (voices, 0..) |*voice, i| {
        const releasing = voice.envelope_stage == .release or voice.envelope_stage == .idle;
        if (steal_idx == null) {
            steal_idx = i;
            steal_env = voice.envelope_value;
            continue;
        }
        const best_releasing = voices[steal_idx.?].envelope_stage == .release or
            voices[steal_idx.?].envelope_stage == .idle;
        if ((releasing and !best_releasing) or
            (releasing == best_releasing and voice.envelope_value < steal_env))
        {
            steal_idx = i;
            steal_env = voice.envelope_value;
        }
    }

    const idx = steal_idx.?;
    // Clear stale routing from whichever channel previously owned this voice
    for (0..8) |ch| {
        if (channel_voices[ch] == idx) {
            channel_voices[ch] = null;
        }
    }
    return idx;
}

pub const Waveform = enum {
    sine,
    square,
    sawtooth,
    triangle,
    noise,
};

pub const FilterType = enum {
    lowpass,
    highpass,
    bandpass,
    none,
};

pub const ParameterLock = struct {
    pitch_bend: ?f32 = null,     // -1.0 to 1.0 (semitones)
    filter_cutoff: ?f32 = null,   // 0.0 to 1.0
    filter_resonance: ?f32 = null,// 0.0 to 1.0
    volume: ?f32 = null,          // 0.0 to 1.0
    pan: ?f32 = null,             // -1.0 (left) to 1.0 (right)
    waveform: ?Waveform = null,
    duty_cycle: ?f32 = null,      // 0.0 to 1.0 (for square/pulse)
    detune: ?f32 = null,          // cents
    portamento: ?f32 = null,      // speed
};

pub const Voice = struct {
    sample_rate: f32,
    active: bool,
    note: u8,
    velocity: f32,
    phase: f32,
    phase_increment: f32,
    waveform: Waveform,
    duty_cycle: f32,

    // ADSR envelope
    attack: f32,
    decay: f32,
    sustain: f32,
    release_time: f32,
    envelope_phase: f32,
    envelope_value: f32,
    envelope_stage: EnvelopeStage,

    // Filter state
    filter_type: FilterType,
    filter_cutoff: f32,     // 0.0 to 1.0, mapped to Hz
    filter_resonance: f32,  // 0.0 to 1.0
    filter_state_0: f32,
    filter_state_1: f32,
    filter_state_2: f32,
    filter_state_3: f32,

    // Parameter locks (applied per-step)
    current_locks: ParameterLock,
    base_frequency: f32,
    current_pan: f32,
    current_volume: f32,

    pub const EnvelopeStage = enum {
        idle,
        attack,
        decay,
        sustain,
        release,
    };

    pub fn init(sample_rate: u32) Voice {
        return Voice{
            .sample_rate = @floatFromInt(sample_rate),
            .active = false,
            .note = 0,
            .velocity = 0.0,
            .phase = 0.0,
            .phase_increment = 0.0,
            .waveform = .sawtooth,
            .duty_cycle = 0.5,
            .attack = 0.01,
            .decay = 0.3,
            .sustain = 0.7,
            .release_time = 0.5,
            .envelope_phase = 0.0,
            .envelope_value = 0.0,
            .envelope_stage = .idle,
            .filter_type = .none,
            .filter_cutoff = 1.0,
            .filter_resonance = 0.0,
            .filter_state_0 = 0.0,
            .filter_state_1 = 0.0,
            .filter_state_2 = 0.0,
            .filter_state_3 = 0.0,
            .current_locks = .{},
            .base_frequency = 0.0,
            .current_pan = 0.0,
            .current_volume = 1.0,
        };
    }

    pub fn trigger(self: *Voice, note: u8, velocity: u8, locks: ?ParameterLock) void {
        self.active = true;
        self.note = note;
        self.velocity = @as(f32, @floatFromInt(velocity)) / 127.0;
        self.phase = 0.0;

        // Calculate frequency from MIDI note
        const freq = 440.0 * std.math.pow(f32, 2.0, (@as(f32, @floatFromInt(note)) - 69.0) / 12.0);
        self.base_frequency = freq;
        self.phase_increment = freq / self.sample_rate;

        self.envelope_stage = .attack;
        self.envelope_phase = 0.0;
        self.envelope_value = 0.0;

        // Reset filter state
        self.filter_state_0 = 0.0;
        self.filter_state_1 = 0.0;
        self.filter_state_2 = 0.0;
        self.filter_state_3 = 0.0;

        // Apply parameter locks if provided
        if (locks) |l| {
            self.current_locks = l;
            if (l.pan) |p| self.current_pan = p;
            if (l.volume) |v| self.current_volume = v;
            if (l.waveform) |w| self.waveform = w;
            if (l.filter_cutoff) |c| self.filter_cutoff = c;
            if (l.filter_resonance) |r| self.filter_resonance = r;
            if (l.duty_cycle) |d| self.duty_cycle = d;
        } else {
            self.current_locks = .{};
        }
    }

    pub fn release(self: *Voice) void {
        self.envelope_stage = .release;
        self.envelope_phase = 0.0;
    }

    pub fn render(self: *Voice) [2]f32 {
        if (!self.active) return .{ 0.0, 0.0 };

        // Update envelope
        self.updateEnvelope();

        // Apply pitch bend if locked
        var freq = self.base_frequency;
        if (self.current_locks.pitch_bend) |pb| {
            freq *= std.math.pow(f32, 2.0, pb / 12.0);
        }
        if (self.current_locks.detune) |dt| {
            freq *= std.math.pow(f32, 2.0, dt / 1200.0);
        }
        self.phase_increment = freq / self.sample_rate;

        // Generate waveform
        const sample = self.generateWaveform();

        // Apply filter
        const filtered = self.applyFilter(sample);

        // Apply envelope and velocity and volume lock
        const output = filtered * self.envelope_value * self.velocity * self.current_volume;

        // Pan: -1 = left, 0 = center, 1 = right
        const pan = std.math.clamp(self.current_pan, -1.0, 1.0);
        const left = if (pan <= 0.0) 1.0 else 1.0 - pan;
        const right = if (pan >= 0.0) 1.0 else 1.0 + pan;

        // Check if voice is done
        if (self.envelope_stage == .idle) {
            self.active = false;
        }

        // Advance phase
        self.phase += self.phase_increment;
        if (self.phase >= 1.0) {
            self.phase -= 1.0;
        }

        return .{ output * left, output * right };
    }

    fn updateEnvelope(self: *Voice) void {
        switch (self.envelope_stage) {
            .idle => {},
            .attack => {
                self.envelope_phase += 1.0 / (self.attack * self.sample_rate);
                if (self.envelope_phase >= 1.0) {
                    self.envelope_phase = 0.0;
                    self.envelope_value = 1.0;
                    self.envelope_stage = .decay;
                } else {
                    self.envelope_value = self.envelope_phase;
                }
            },
            .decay => {
                self.envelope_phase += 1.0 / (self.decay * self.sample_rate);
                if (self.envelope_phase >= 1.0) {
                    self.envelope_phase = 0.0;
                    self.envelope_value = self.sustain;
                    self.envelope_stage = .sustain;
                } else {
                    self.envelope_value = 1.0 - (1.0 - self.sustain) * self.envelope_phase;
                }
            },
            .sustain => {
                self.envelope_value = self.sustain;
            },
            .release => {
                self.envelope_phase += 1.0 / (self.release_time * self.sample_rate);
                if (self.envelope_phase >= 1.0) {
                    self.envelope_phase = 0.0;
                    self.envelope_value = 0.0;
                    self.envelope_stage = .idle;
                } else {
                    self.envelope_value = self.sustain * (1.0 - self.envelope_phase);
                }
            },
        }
    }

    fn generateWaveform(self: *Voice) f32 {
        switch (self.waveform) {
            .sine => {
                return std.math.sin(self.phase * 2.0 * std.math.pi);
            },
            .square => {
                return if (self.phase < self.duty_cycle) 1.0 else -1.0;
            },
            .sawtooth => {
                return self.phase * 2.0 - 1.0;
            },
            .triangle => {
                if (self.phase < 0.25) {
                    return self.phase * 4.0;
                } else if (self.phase < 0.75) {
                    return 1.0 - (self.phase - 0.25) * 4.0;
                } else {
                    return -1.0 + (self.phase - 0.75) * 4.0;
                }
            },
            .noise => {
                var seed = @as(u32, @bitCast(self.phase * 100000.0 + self.note));
                seed = seed *% 1103515245 +% 12345;
                const r = @as(f32, @floatFromInt(seed % 1000)) / 500.0 - 1.0;
                return r;
            },
        }
    }

    fn applyFilter(self: *Voice, input: f32) f32 {
        if (self.filter_type == .none) return input;

        // Map cutoff 0.0-1.0 to 20Hz-20kHz
        const cutoff_hz = 20.0 + self.filter_cutoff * 19980.0;
        const resonance = self.filter_resonance * 4.0;

        // Chamberlin state-variable filter. f must stay below ~1 for
        // stability, which limits the effective cutoff to ~sample_rate/6;
        // higher cutoffs simply saturate fully open.
        const f = @min(2.0 * std.math.sin(std.math.pi * cutoff_hz / self.sample_rate), 1.0);
        const q = 1.0 / (1.0 + resonance);

        self.filter_state_1 += f * self.filter_state_2; // low += f * band
        self.filter_state_0 = input - self.filter_state_1 - q * self.filter_state_2; // high
        self.filter_state_2 += f * self.filter_state_0; // band += f * high

        return switch (self.filter_type) {
            .lowpass => self.filter_state_1,
            .highpass => self.filter_state_0,
            .bandpass => self.filter_state_2,
            .none => input,
        };
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

fn renderN(v: *Voice, n: usize) [2]f32 {
    var out: [2]f32 = .{ 0.0, 0.0 };
    for (0..n) |_| {
        out = v.render();
    }
    return out;
}

fn testVoice(sample_rate: u32) Voice {
    var v = Voice.init(sample_rate);
    v.attack = 0.001;
    v.decay = 0.001;
    v.sustain = 0.6;
    v.release_time = 0.001;
    return v;
}

test "trigger activates voice and sets frequency" {
    var v = testVoice(48000);
    try testing.expect(!v.active);

    v.trigger(69, 127, null);
    try testing.expect(v.active);
    try testing.expectEqual(@as(u8, 69), v.note);
    try testing.expectEqual(@as(f32, 1.0), v.velocity);
    try testing.expectApproxEqAbs(@as(f32, 440.0), v.base_frequency, 0.01);
    try testing.expectEqual(Voice.EnvelopeStage.attack, v.envelope_stage);

    // A4 -> A5 doubles the frequency
    v.trigger(81, 64, null);
    try testing.expectApproxEqAbs(@as(f32, 880.0), v.base_frequency, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 64.0 / 127.0), v.velocity, 0.0001);
}

test "trigger applies parameter locks" {
    var v = testVoice(48000);
    const locks: ParameterLock = .{
        .volume = 0.5,
        .pan = 1.0,
        .waveform = .square,
        .duty_cycle = 0.25,
    };
    v.trigger(60, 100, locks);
    try testing.expectEqual(@as(f32, 0.5), v.current_volume);
    try testing.expectEqual(@as(f32, 1.0), v.current_pan);
    try testing.expectEqual(Waveform.square, v.waveform);
    try testing.expectEqual(@as(f32, 0.25), v.duty_cycle);
}

test "adsr attack rises to peak" {
    var v = testVoice(48000);
    v.trigger(60, 127, null);

    // First render: envelope has begun to rise but is not yet at peak
    var last: f32 = 0.0;
    var rose = false;
    var i: usize = 0;
    while (i < 480) : (i += 1) { // 10ms at 48k covers a 1ms attack
        _ = v.render();
        if (v.envelope_value > last) rose = true;
        last = v.envelope_value;
        if (v.envelope_stage != .attack) break;
    }
    try testing.expect(rose);
    try testing.expectEqual(@as(f32, 1.0), v.envelope_value);
}

test "adsr decay falls to sustain and holds" {
    var v = testVoice(48000);
    v.trigger(60, 127, null);

    // Run through attack + decay + a generous sustain dwell
    var saw_sustain = false;
    var i: usize = 0;
    while (i < 4800) : (i += 1) { // 100ms covers attack+decay many times over
        _ = v.render();
        if (v.envelope_stage == .sustain) saw_sustain = true;
    }
    try testing.expect(saw_sustain);
    try testing.expectEqual(Voice.EnvelopeStage.sustain, v.envelope_stage);
    try testing.expectEqual(@as(f32, 0.6), v.envelope_value);
    try testing.expect(v.active);
}

test "adsr release falls to silence and deactivates" {
    var v = testVoice(48000);
    v.trigger(60, 127, null);

    // Get to sustain first
    var i: usize = 0;
    while (i < 4800) : (i += 1) _ = v.render();
    try testing.expectEqual(Voice.EnvelopeStage.sustain, v.envelope_stage);

    v.release();
    try testing.expectEqual(Voice.EnvelopeStage.release, v.envelope_stage);

    var fell = false;
    var last: f32 = 1.0;
    i = 0;
    while (i < 4800) : (i += 1) {
        _ = v.render();
        if (v.envelope_value < last) fell = true;
        last = v.envelope_value;
        if (!v.active) break;
    }
    try testing.expect(fell);
    try testing.expect(!v.active);
    try testing.expectEqual(@as(f32, 0.0), v.envelope_value);

    // Inactive voice renders digital silence
    const out = v.render();
    try testing.expectEqual(@as(f32, 0.0), out[0]);
    try testing.expectEqual(@as(f32, 0.0), out[1]);
}

test "sine is bounded within -1..1" {
    var v = testVoice(48000);
    v.waveform = .sine;
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        v.phase = @as(f32, @floatFromInt(i)) / 1000.0;
        const s = v.generateWaveform();
        try testing.expect(s >= -1.0 and s <= 1.0);
    }
    // Known points
    v.phase = 0.0;
    try testing.expectApproxEqAbs(@as(f32, 0.0), v.generateWaveform(), 0.0001);
    v.phase = 0.25;
    try testing.expectApproxEqAbs(@as(f32, 1.0), v.generateWaveform(), 0.0001);
}

test "square respects duty cycle" {
    var v = testVoice(48000);
    v.waveform = .square;
    v.duty_cycle = 0.25;

    v.phase = 0.1;
    try testing.expectEqual(@as(f32, 1.0), v.generateWaveform());
    v.phase = 0.24;
    try testing.expectEqual(@as(f32, 1.0), v.generateWaveform());
    v.phase = 0.25;
    try testing.expectEqual(@as(f32, -1.0), v.generateWaveform());
    v.phase = 0.9;
    try testing.expectEqual(@as(f32, -1.0), v.generateWaveform());
}

test "sawtooth ramps from -1 to 1" {
    var v = testVoice(48000);
    v.waveform = .sawtooth;

    v.phase = 0.0;
    try testing.expectEqual(@as(f32, -1.0), v.generateWaveform());
    v.phase = 0.5;
    try testing.expectEqual(@as(f32, 0.0), v.generateWaveform());
    v.phase = 0.75;
    try testing.expectEqual(@as(f32, 0.5), v.generateWaveform());
}

test "triangle peaks at quarter phase" {
    var v = testVoice(48000);
    v.waveform = .triangle;

    v.phase = 0.0;
    try testing.expectEqual(@as(f32, 0.0), v.generateWaveform());
    v.phase = 0.25;
    try testing.expectEqual(@as(f32, 1.0), v.generateWaveform());
    v.phase = 0.5;
    try testing.expectEqual(@as(f32, 0.0), v.generateWaveform());
    v.phase = 0.75;
    try testing.expectEqual(@as(f32, -1.0), v.generateWaveform());
}

test "noise is deterministic for identical state" {
    var a = testVoice(48000);
    var b = testVoice(48000);
    a.waveform = .noise;
    b.waveform = .noise;
    a.note = 60;
    b.note = 60;

    var i: usize = 0;
    while (i < 64) : (i += 1) {
        const p = @as(f32, @floatFromInt(i)) / 64.0;
        a.phase = p;
        b.phase = p;
        const sa = a.generateWaveform();
        const sb = b.generateWaveform();
        try testing.expectEqual(sa, sb);
        try testing.expect(sa >= -1.0 and sa <= 1.0);
    }
}

test "render honors pan lock" {
    var v = testVoice(48000);
    v.trigger(60, 127, .{ .pan = 1.0 }); // hard right

    var i: usize = 0;
    while (i < 200) : (i += 1) _ = v.render(); // past attack
    const out = v.render();
    try testing.expectEqual(@as(f32, 0.0), out[0]); // nothing on the left
    try testing.expect(out[1] != 0.0); // signal on the right
}

test "filter none passes signal through" {
    var v = testVoice(48000);
    v.filter_type = .none;
    try testing.expectEqual(@as(f32, 0.42), v.applyFilter(0.42));
}

test "lowpass filter attenuates high frequency content" {
    var lp = testVoice(48000);
    lp.filter_type = .lowpass;
    lp.filter_cutoff = 0.01; // ~220Hz cutoff
    lp.filter_resonance = 0.0;

    var unfiltered = testVoice(48000);

    // Feed a high-frequency square-ish alternating signal
    var lp_energy: f32 = 0.0;
    var raw_energy: f32 = 0.0;
    var i: usize = 0;
    while (i < 4800) : (i += 1) {
        const input: f32 = if (i % 2 == 0) 1.0 else -1.0;
        const filtered = lp.applyFilter(input);
        const raw = unfiltered.applyFilter(input);
        if (i > 2400) { // let the filter settle
            lp_energy += @abs(filtered);
            raw_energy += @abs(raw);
        }
    }
    try testing.expect(lp_energy < raw_energy * 0.5);
}

test "allocateVoice prefers channel reuse then first free" {
    var voices: [4]Voice = undefined;
    for (&voices) |*v| v.* = Voice.init(48000);
    var channel_voices: [8]?usize = .{null} ** 8;

    // All free: first free voice
    try testing.expectEqual(@as(?usize, 0), allocateVoice(&voices, &channel_voices, 0));
    channel_voices[0] = 0;
    voices[0].active = true;

    // Channel 0's voice is busy: take next free
    try testing.expectEqual(@as(?usize, 1), allocateVoice(&voices, &channel_voices, 0));

    // Channel 0's voice freed: reuse it
    voices[0].active = false;
    try testing.expectEqual(@as(?usize, 0), allocateVoice(&voices, &channel_voices, 0));
}

test "allocateVoice steals quietest releasing voice at polyphony limit" {
    var voices: [2]Voice = undefined;
    for (&voices) |*v| v.* = Voice.init(48000);
    var channel_voices: [8]?usize = .{null} ** 8;

    // Fill both voices
    voices[0].trigger(60, 127, null);
    voices[1].trigger(64, 127, null);
    channel_voices[0] = 0;
    channel_voices[1] = 1;

    // Put voice 1 into release: it should be stolen first
    _ = renderN(&voices[0], 4);
    _ = renderN(&voices[1], 4);
    voices[1].release();
    _ = renderN(&voices[1], 8);

    const idx = allocateVoice(&voices, &channel_voices, 2);
    try testing.expectEqual(@as(?usize, 1), idx);
    // Stale routing for the stolen voice is cleared
    try testing.expectEqual(@as(?usize, null), channel_voices[1]);
}

test "empty voice list returns null" {
    var channel_voices: [8]?usize = .{null} ** 8;
    try testing.expectEqual(@as(?usize, null), allocateVoice(&.{}, &channel_voices, 0));
}

