const std = @import("std");
const audio = @import("audio/engine.zig");
const midi = @import("midi/input.zig");
const tracker = @import("tracker/pattern.zig");
const ui = @import("ui/screen.zig");
const synth = @import("synth/voice.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🎹 GridTracker v0.1.0 — Terminal Music Tracker\n", .{});
    std.debug.print("Zig + PortAudio + PortMidi\n\n", .{});

    // Initialize audio engine
    var engine = try audio.Engine.init(allocator, 48000, 256);
    defer engine.deinit();

    // Initialize MIDI input
    var midi_input = try midi.Input.init(allocator);
    defer midi_input.deinit();

    // Create tracker pattern
    var pattern = try tracker.Pattern.init(allocator, 64, 8); // 64 rows, 8 channels
    defer pattern.deinit();

    // Initialize UI
    var screen = try ui.Screen.init(allocator, &engine, &pattern);
    defer screen.deinit();

    // Main loop
    try screen.run();
}
