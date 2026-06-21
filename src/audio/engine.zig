const std = @import("std");
const c = @cImport({
    @cInclude("portaudio.h");
});

const Voice = @import("../synth/voice.zig").Voice;
const Mixer = @import("mixer.zig").Mixer;
const Sequencer = @import("../tracker/pattern.zig").Sequencer;
const NoteEvent = @import("../tracker/pattern.zig").NoteEvent;

pub const Engine = struct {
    allocator: std.mem.Allocator,
    sample_rate: f32,
    buffer_size: u32,
    stream: ?*c.PaStream,
    voices: std.ArrayList(Voice),
    mixer: Mixer,
    sequencer: ?*Sequencer,
    channel_voices: [8]?usize, // which voice index is active per channel
    voice_lock: std.atomic.Value(u32),

    pub fn init(allocator: std.mem.Allocator, sample_rate: u32, buffer_size: u32) !Engine {
        const err = c.Pa_Initialize();
        if (err != c.paNoError) {
            std.debug.print("PortAudio init failed: {s}\n", .{c.Pa_GetErrorText(err)});
            return error.PortAudioInitFailed;
        }

        var voices = try std.ArrayList(Voice).initCapacity(allocator, 32);
        for (0..32) |_| {
            try voices.append(allocator, Voice.init(sample_rate));
        }

        const engine = Engine{
            .allocator = allocator,
            .sample_rate = @floatFromInt(sample_rate),
            .buffer_size = buffer_size,
            .stream = null,
            .voices = voices,
            .mixer = Mixer.init(),
            .sequencer = null,
            .channel_voices = .{null} ** 8,
            .voice_lock = std.atomic.Value(u32).init(0),
        };
        return engine;
    }

    pub fn deinit(self: *Engine) void {
        if (self.stream) |stream| {
            _ = c.Pa_CloseStream(stream);
            self.stream = null;
        }
        _ = c.Pa_Terminate();
        self.voices.deinit(self.allocator);
    }

    pub fn setSequencer(self: *Engine, seq: *Sequencer) void {
        self.sequencer = seq;
    }

    fn acquireLock(self: *Engine) void {
        while (self.voice_lock.cmpxchgStrong(0, 1, .acquire, .monotonic) != null) {
            std.atomic.spinLoopHint();
        }
    }

    fn releaseLock(self: *Engine) void {
        self.voice_lock.store(0, .release);
    }

    pub fn start(self: *Engine) !void {
        const callback = struct {
            pub fn audioCallback(
                input_buffer: ?*const anyopaque,
                output_buffer: ?*anyopaque,
                frames_per_buffer: c_ulong,
                time_info: [*c]const c.PaStreamCallbackTimeInfo,
                status_flags: c.PaStreamCallbackFlags,
                user_data: ?*anyopaque,
            ) callconv(.c) c_int {
                _ = input_buffer;
                _ = time_info;
                _ = status_flags;
                const engine = @as(*Engine, @ptrCast(@alignCast(user_data)));
                const out = @as([*c]f32, @ptrCast(@alignCast(output_buffer)));

                engine.acquireLock();
                defer engine.releaseLock();

                // Process sequencer
                if (engine.sequencer) |seq| {
                    if (seq.tick()) |notes| {
                        for (notes) |note| {
                            engine.triggerNoteEvent(note);
                        }
                    }
                }

                var frame: u32 = 0;
                while (frame < frames_per_buffer) : (frame += 1) {
                    var left: f32 = 0.0;
                    var right: f32 = 0.0;
                    for (engine.voices.items, 0..) |*voice, vi| {
                        if (voice.active) {
                            const stereo = voice.render();
                            // Find which channel this voice belongs to
                            var ch: usize = 0;
                            for (0..8) |ci| {
                                if (engine.channel_voices[ci] == vi) {
                                    ch = ci;
                                    break;
                                }
                            }
                            const mixed = engine.mixer.process(ch, stereo);
                            left += mixed[0];
                            right += mixed[1];
                        }
                    }
                    out[frame * 2] = left;
                    out[frame * 2 + 1] = right;
                }

                return c.paContinue;
            }
        }.audioCallback;

        var stream: ?*c.PaStream = null;
        const err = c.Pa_OpenDefaultStream(
            &stream,
            0,
            2,
            c.paFloat32,
            @as(f64, self.sample_rate),
            self.buffer_size,
            callback,
            self,
        );
        if (err != c.paNoError) {
            std.debug.print("PortAudio open stream failed: {s}\n", .{c.Pa_GetErrorText(err)});
            return error.PortAudioStreamFailed;
        }

        self.stream = stream;
        const start_err = c.Pa_StartStream(stream);
        if (start_err != c.paNoError) {
            std.debug.print("PortAudio start stream failed: {s}\n", .{c.Pa_GetErrorText(start_err)});
            return error.PortAudioStreamFailed;
        }
    }

    pub fn stop(self: *Engine) void {
        if (self.stream) |stream| {
            _ = c.Pa_StopStream(stream);
        }
    }

    pub fn triggerNoteEvent(self: *Engine, event: NoteEvent) void {
        self.acquireLock();
        defer self.releaseLock();

        // Find a free voice, prefer same channel
        const ch = event.instrument % 8;
        var voice_idx: ?usize = null;

        // Try to reuse voice on same channel
        if (self.channel_voices[ch]) |cv| {
            if (!self.voices.items[cv].active) {
                voice_idx = cv;
            }
        }

        // Find any free voice
        if (voice_idx == null) {
            for (self.voices.items, 0..) |*voice, i| {
                if (!voice.active) {
                    voice_idx = i;
                    break;
                }
            }
        }

        if (voice_idx) |vi| {
            self.channel_voices[ch] = vi;
            var locks = event.locks;
            // Apply default volume/pan from mixer if not locked
            if (locks.volume == null) locks.volume = self.mixer.channels[ch].volume;
            if (locks.pan == null) locks.pan = self.mixer.channels[ch].pan;
            self.voices.items[vi].trigger(event.note, event.volume * 2, locks);
        }
    }

    pub fn triggerNote(self: *Engine, note: u8, velocity: u8) void {
        self.acquireLock();
        defer self.releaseLock();

        for (self.voices.items, 0..) |*voice, i| {
            if (!voice.active) {
                self.channel_voices[0] = i;
                voice.trigger(note, velocity, null);
                break;
            }
        }
    }

    pub fn releaseNote(self: *Engine, note: u8) void {
        self.acquireLock();
        defer self.releaseLock();

        for (self.voices.items) |*voice| {
            if (voice.active and voice.note == note) {
                voice.release();
            }
        }
    }
};
