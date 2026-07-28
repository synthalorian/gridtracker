const std = @import("std");
const audio = @import("audio/engine.zig");
const midi = @import("midi/input.zig");
const tracker = @import("tracker/pattern.zig");
const ui = @import("ui/screen.zig");
const synth = @import("synth/voice.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var io_threaded: std.Io.Threaded = .init(allocator, .{});
    defer io_threaded.deinit();
    const io = io_threaded.io();

    std.debug.print("🎹 GridTracker v1.0.0 — Terminal Music Tracker\n", .{});
    std.debug.print("Zig + PortAudio + PortMidi\n\n", .{});

    // Initialize audio engine
    var engine = try audio.Engine.init(allocator, 48000, 256);
    defer engine.deinit();

    // Initialize MIDI input
    var midi_input = try midi.Input.init(allocator);
    defer midi_input.deinit();

    // Create sequencer with 256 patterns and 8 channels
    var sequencer = try tracker.Sequencer.init(allocator, 48000);
    defer sequencer.deinit();

    // Wire sequencer to audio engine
    engine.setSequencer(&sequencer);

    // Initialize UI
    var screen = try ui.Screen.init(allocator, &engine, &sequencer, &midi_input, io);
    defer screen.deinit();

    // Main loop
    try screen.run();
}
