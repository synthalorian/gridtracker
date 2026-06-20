const std = @import("std");
const c = @cImport({
    @cInclude("portaudio.h");
});

const Voice = @import("../synth/voice.zig").Voice;

pub const Engine = struct {
    allocator: std.mem.Allocator,
    sample_rate: f32,
    buffer_size: u32,
    stream: ?*c.PaStream,
    voices: std.ArrayList(Voice),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, sample_rate: u32, buffer_size: u32) !Engine {
        const err = c.Pa_Initialize();
        if (err != c.paNoError) {
            std.debug.print("PortAudio init failed: {s}\n", .{c.Pa_GetErrorText(err)});
            return error.PortAudioInitFailed;
        }

        var voices = std.ArrayList(Voice).init(allocator);
        // Pre-allocate 32 polyphonic voices
        try voices.resize(32);
        for (voices.items) |*voice| {
            voice.* = Voice.init(sample_rate);
        }

        return Engine{
            .allocator = allocator,
            .sample_rate = @floatFromInt(sample_rate),
            .buffer_size = buffer_size,
            .stream = null,
            .voices = voices,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Engine) void {
        if (self.stream) |stream| {
            _ = c.Pa_CloseStream(stream);
            self.stream = null;
        }
        _ = c.Pa_Terminate();
        self.voices.deinit();
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
            ) callconv(.C) c_int {
                _ = input_buffer;
                _ = time_info;
                _ = status_flags;
                const engine = @as(*Engine, @ptrCast(@alignCast(user_data)));
                const out = @as([*c]f32, @ptrCast(@alignCast(output_buffer)));

                engine.mutex.lock();
                defer engine.mutex.unlock();

                var frame: u32 = 0;
                while (frame < frames_per_buffer) : (frame += 1) {
                    var sample: f32 = 0.0;
                    for (engine.voices.items) |*voice| {
                        if (voice.active) {
                            sample += voice.render();
                        }
                    }
                    // Stereo output
                    out[frame * 2] = sample * 0.3;
                    out[frame * 2 + 1] = sample * 0.3;
                }

                return c.paContinue;
            }
        }.audioCallback;

        var stream: ?*c.PaStream = null;
        const err = c.Pa_OpenDefaultStream(
            &stream,
            0, // no input
            2, // stereo output
            c.paFloat32,
            @floatFromInt(self.sample_rate),
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

    pub fn triggerNote(self: *Engine, note: u8, velocity: u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Find free voice
        for (self.voices.items) |*voice| {
            if (!voice.active) {
                voice.trigger(note, velocity);
                break;
            }
        }
    }

    pub fn releaseNote(self: *Engine, note: u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.voices.items) |*voice| {
            if (voice.active and voice.note == note) {
                voice.release();
            }
        }
    }
};
