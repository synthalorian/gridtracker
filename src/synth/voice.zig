const std = @import("std");

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

        // Simple state-variable filter (Chamberlin)
        const f = 2.0 * std.math.sin(std.math.pi * cutoff_hz / self.sample_rate);
        const q = 1.0 / (1.0 + resonance);

        self.filter_state_3 = self.filter_state_3 + f * self.filter_state_2;
        self.filter_state_0 = input - self.filter_state_3 - q * self.filter_state_1;
        self.filter_state_1 = self.filter_state_1 + f * self.filter_state_0;
        self.filter_state_2 = self.filter_state_2 + f * self.filter_state_1;

        return switch (self.filter_type) {
            .lowpass => self.filter_state_1,
            .highpass => self.filter_state_0,
            .bandpass => self.filter_state_2,
            .none => input,
        };
    }
};
