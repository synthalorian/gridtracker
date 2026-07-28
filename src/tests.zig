const std = @import("std");

// Unit test entry point. Pulls the pure-logic modules into a single
// `zig build test` run. These tests are headless: no audio hardware,
// MIDI devices, or terminal required.
comptime {
    std.testing.refAllDecls(@import("synth/voice.zig"));
    std.testing.refAllDecls(@import("tracker/pattern.zig"));
    std.testing.refAllDecls(@import("audio/mixer.zig"));
}
