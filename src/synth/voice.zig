const std = @import("std");

pub const Waveform = enum {
    sine,
    square,
    sawtooth,
    triangle,
    noise,
};

pub const Voice = struct {
    sample_rate: f32,
    active: bool,
    note: u8,
    velocity: f32,
    phase: f32,
    phase_increment: f32,
    waveform: Waveform,
    
    // ADSR envelope
    attack: f32,
    decay: f32,
    sustain: f32,
    release: f32,
    envelope_phase: f32,
    envelope_value: f32,
    envelope_stage: EnvelopeStage,

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
            .attack = 0.01,
            .decay = 0.3,
            .sustain = 0.7,
            .release = 0.5,
            .envelope_phase = 0.0,
            .envelope_value = 0.0,
            .envelope_stage = .idle,
        };
    }

    pub fn trigger(self: *Voice, note: u8, velocity: u8) void {
        self.active = true;
        self.note = note;
        self.velocity = @as(f32, @floatFromInt(velocity)) / 127.0;
        self.phase = 0.0;
        
        // Calculate frequency from MIDI note
        const freq = 440.0 * std.math.pow(f32, 2.0, (@as(f32, @floatFromInt(note)) - 69.0) / 12.0);
        self.phase_increment = freq / self.sample_rate;
        
        self.envelope_stage = .attack;
        self.envelope_phase = 0.0;
        self.envelope_value = 0.0;
    }

    pub fn release(self: *Voice) void {
        self.envelope_stage = .release;
        self.envelope_phase = 0.0;
    }

    pub fn render(self: *Voice) f32 {
        if (!self.active) return 0.0;

        // Update envelope
        self.updateEnvelope();

        // Generate waveform
        const sample = self.generateWaveform();

        // Apply envelope and velocity
        const output = sample * self.envelope_value * self.velocity;

        // Check if voice is done
        if (self.envelope_stage == .idle) {
            self.active = false;
        }

        // Advance phase
        self.phase += self.phase_increment;
        if (self.phase >= 1.0) {
            self.phase -= 1.0;
        }

        return output;
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
                self.envelope_phase += 1.0 / (self.release * self.sample_rate);
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
                return if (self.phase < 0.5) 1.0 else -1.0;
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
                // Simple pseudo-random noise
                const seed = @as(u32, @bitCast(self.phase * 100000.0));
                const random = std.hash.Crc32.hash(std.mem.asBytes(&seed));
                return (@as(f32, @floatFromInt(random % 1000)) / 500.0) - 1.0;
            },
        }
    }
};
