const std = @import("std");
const audio = @import("../audio/engine.zig");
const tracker = @import("../tracker/pattern.zig");

pub const Screen = struct {
    allocator: std.mem.Allocator,
    engine: *audio.Engine,
    pattern: *tracker.Pattern,
    running: bool,
    cursor_row: u32,
    cursor_channel: u32,

    pub fn init(allocator: std.mem.Allocator, engine: *audio.Engine, pattern: *tracker.Pattern) !Screen {
        return Screen{
            .allocator = allocator,
            .engine = engine,
            .pattern = pattern,
            .running = true,
            .cursor_row = 0,
            .cursor_channel = 0,
        };
    }

    pub fn deinit(self: *Screen) void {
        _ = self;
    }

    pub fn run(self: *Screen) !void {
        // Start audio engine
        try self.engine.start();
        defer self.engine.stop();

        std.debug.print("\nGridTracker started! Press keys to interact:\n", .{});
        std.debug.print("  [Space] - Play/Stop pattern\n", .{});
        std.debug.print("  [↑/↓] - Move cursor\n", .{});
        std.debug.print("  [a-z] - Enter note\n", .{});
        std.debug.print("  [q] - Quit\n\n", .{});

        // Simple terminal UI loop
        const stdin = std.io.getStdIn().reader();
        var buf: [1]u8 = undefined;

        while (self.running) {
            // Draw pattern
            try self.draw();

            // Read input
            const read = try stdin.read(&buf);
            if (read == 0) continue;

            switch (buf[0]) {
                'q', 'Q' => self.running = false,
                ' ' => {
                    if (self.pattern.is_playing) {
                        self.pattern.stop();
                        std.debug.print("\nStopped.\n", .{});
                    } else {
                        self.pattern.play();
                        std.debug.print("\nPlaying...\n", .{});
                    }
                },
                'w', 'W' => {
                    if (self.cursor_row > 0) self.cursor_row -= 1;
                },
                's', 'S' => {
                    if (self.cursor_row < self.pattern.rows - 1) self.cursor_row += 1;
                },
                'a', 'A' => {
                    if (self.cursor_channel > 0) self.cursor_channel -= 1;
                },
                'd', 'D' => {
                    if (self.cursor_channel < self.pattern.channels - 1) self.cursor_channel += 1;
                },
                // Note entry (simplified - C-4 to B-4 range)
                'z' => self.setNote(60), // C-4
                'x' => self.setNote(62), // D-4
                'c' => self.setNote(64), // E-4
                'v' => self.setNote(65), // F-4
                'b' => self.setNote(67), // G-4
                'n' => self.setNote(69), // A-4
                'm' => self.setNote(71), // B-4
                ',' => self.setNote(72), // C-5
                '0' => self.clearNote(),
                else => {},
            }
        }

        std.debug.print("\nGoodbye! 🎹\n", .{});
    }

    fn draw(self: *Screen) !void {
        // Clear screen (ANSI escape)
        std.debug.print("\x1B[2J\x1B[H", .{});
        std.debug.print("🎹 GridTracker — Row {d:02}/{d:02} | Ch {d}/{d} | BPM {d:.0}\n", .{
            self.cursor_row, self.pattern.rows,
            self.cursor_channel + 1, self.pattern.channels,
            self.pattern.bpm,
        });
        std.debug.print("═" ** 60 ++ "\n", .{});

        // Show visible rows (16 at a time)
        const start_row = if (self.cursor_row > 8) self.cursor_row - 8 else 0;
        const end_row = @min(start_row + 16, self.pattern.rows);

        var row: u32 = start_row;
        while (row < end_row) : (row += 1) {
            const is_cursor_row = row == self.cursor_row;
            if (is_cursor_row) {
                std.debug.print("> ", .{});
            } else {
                std.debug.print("  ", .{});
            }
            std.debug.print("{d:02} | ", .{row});

            for (0..self.pattern.channels) |ch| {
                if (is_cursor_row and ch == self.cursor_channel) {
                    std.debug.print("[", .{});
                } else {
                    std.debug.print(" ", .{});
                }

                if (self.pattern.getNote(row, @intCast(ch))) |note| {
                    const note_names = [_][]const u8{"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"};
                    const name = note_names[note.note % 12];
                    const octave = note.note / 12;
                    std.debug.print("{s}{d} ", .{name, octave});
                } else {
                    std.debug.print("... ", .{});
                }

                if (is_cursor_row and ch == self.cursor_channel) {
                    std.debug.print("]", .{});
                } else {
                    std.debug.print(" ", .{});
                }
                std.debug.print("| ", .{});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("\nControls: [z-m] notes | [wasd] move | [space] play | [0] clear | [q] quit\n", .{});
    }

    fn setNote(self: *Screen, note: u8) void {
        self.pattern.setNote(self.cursor_row, self.cursor_channel, tracker.Pattern.NoteEvent{
            .note = note,
            .instrument = 0,
            .volume = 64,
            .effect = 0,
            .effect_param = 0,
        });
        // Also trigger for immediate feedback
        self.engine.triggerNote(note, 100);
        // Auto-advance cursor
        if (self.cursor_row < self.pattern.rows - 1) {
            self.cursor_row += 1;
        }
    }

    fn clearNote(self: *Screen) void {
        self.pattern.setNote(self.cursor_row, self.cursor_channel, null);
    }
};
