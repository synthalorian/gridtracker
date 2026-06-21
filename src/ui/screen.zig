const std = @import("std");
const audio = @import("../audio/engine.zig");
const tracker = @import("../tracker/pattern.zig");
const synth = @import("../synth/voice.zig");

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("unistd.h");
});

pub const ScreenMode = enum {
    pattern,
    song,
    instrument,
    mixer,
};

pub const Screen = struct {
    allocator: std.mem.Allocator,
    engine: *audio.Engine,
    sequencer: *tracker.Sequencer,
    running: bool,
    cursor_row: u32,
    cursor_channel: u32,
    cursor_param: u32,
    mode: ScreenMode,
    song_cursor: u32,
    inst_cursor: u32,
    mixer_cursor: u32,
    edit_value: ?u8,
    hex_input: [2]u8,
    hex_pos: u8,
    filename_buf: [64]u8,
    filename_len: u8,
    show_help: bool,

    pub fn init(allocator: std.mem.Allocator, engine: *audio.Engine, sequencer: *tracker.Sequencer) !Screen {
        return Screen{
            .allocator = allocator,
            .engine = engine,
            .sequencer = sequencer,
            .running = true,
            .cursor_row = 0,
            .cursor_channel = 0,
            .cursor_param = 0,
            .mode = .pattern,
            .song_cursor = 0,
            .inst_cursor = 0,
            .mixer_cursor = 0,
            .edit_value = null,
            .hex_input = .{ 0, 0 },
            .hex_pos = 0,
            .filename_buf = undefined,
            .filename_len = 0,
            .show_help = false,
        };
    }

    pub fn deinit(self: *Screen) void {
        _ = self;
    }

    pub fn run(self: *Screen) !void {
        try self.engine.start();
        defer self.engine.stop();

        _ = c.printf("GridTracker v0.2.0 started. Press keys to play notes, Space to toggle play, Q to quit.\n");
        _ = c.printf("Keys: z=C-4 x=D-4 c=E-4 v=F-4 b=G-4 n=A-4 m=B-4 ,=C-5\n");
        _ = c.printf("      a=C-3 e=E-3 g=G-3 j=A#3 l=C#4 ;=D#4 u=F#4 o=G#4 k=A#4\n");
        _ = c.printf("      [Space] Play/Stop  [+/-] BPM  [T] Pattern  [G] Song  [Q] Quit\n\n");

        // Set up terminal for raw mode
        const stdin = std.posix.STDIN_FILENO;

        _ = try std.posix.tcgetattr(stdin);
        var raw = try std.posix.tcgetattr(stdin);
        raw.lflag.ICANON = false;
        raw.lflag.ECHO = false;
        raw.lflag.ISIG = false;
        raw.cc[@intFromEnum(std.posix.V.MIN)] = 0;
        raw.cc[@intFromEnum(std.posix.V.TIME)] = 1;
        try std.posix.tcsetattr(stdin, .FLUSH, raw);
        defer {
            var restore = raw;
            restore.lflag.ICANON = true;
            restore.lflag.ECHO = true;
            restore.lflag.ISIG = true;
            _ = std.posix.tcsetattr(stdin, .FLUSH, restore) catch {};
        }

        while (self.running) {
            var buf: [8]u8 = undefined;
            const read = try std.posix.read(stdin, &buf);
            if (read == 0) {
                _ = c.usleep(16000);
                continue;
            }

            // Parse escape sequences
            if (buf[0] == '\x1B' and read >= 3 and buf[1] == '[') {
                switch (buf[2]) {
                    'A' => self.moveUp(),
                    'B' => self.moveDown(),
                    'C' => self.moveRight(),
                    'D' => self.moveLeft(),
                    else => {},
                }
                continue;
            }

            switch (buf[0]) {
                'Q' => self.running = false,
                ' ' => {
                    if (self.sequencer.is_playing) {
                        self.sequencer.stop();
                        _ = c.printf("STOPPED\n");
                    } else {
                        self.sequencer.play();
                        _ = c.printf("PLAYING\n");
                    }
                },
                'W' => self.moveUp(),
                'S' => self.moveDown(),
                'a', 'A' => self.moveLeft(),
                'd', 'D' => self.moveRight(),
                't', 'T' => { self.mode = .pattern; _ = c.printf("PATTERN MODE\n"); },
                'g', 'G' => { self.mode = .song; _ = c.printf("SONG MODE\n"); },
                'i', 'I' => { self.mode = .instrument; _ = c.printf("INSTRUMENT MODE\n"); },
                'm', 'M' => { self.mode = .mixer; _ = c.printf("MIXER MODE\n"); },
                'h', 'H' => self.show_help = !self.show_help,
                '+' => { self.sequencer.setBpm(self.sequencer.bpm + 1); _ = c.printf("BPM: %d\n", self.sequencer.bpm); },
                '-' => { self.sequencer.setBpm(self.sequencer.bpm - 1); _ = c.printf("BPM: %d\n", self.sequencer.bpm); },
                '0' => self.clearNote(),
                '1'...'9' => self.handleDigit(buf[0] - '0'),
                'f', 'F' => self.saveFile(),
                'l', 'L' => self.loadFile(),
                'N' => self.clonePattern(),
                'p', 'P' => self.prevPattern(),
                'x', 'X' => self.nextPattern(),
                'r', 'R' => self.toggleSongMode(),
                // Note entry (computer keyboard mapping like LSDJ)
                'z' => self.setNote(60),
                'y' => self.setNote(62),
                'c' => self.setNote(64),
                'v' => self.setNote(65),
                'b' => self.setNote(67),
                'n' => self.setNote(69),
                'w' => self.setNote(71),
                ',' => self.setNote(72),
                '.' => self.setNote(74),
                '/' => self.setNote(76),
                'e' => self.setNote(52),
                'j' => self.setNote(55),
                'k' => self.setNote(58),
                'u' => self.setNote(61),
                ';' => self.setNote(63),
                'o' => self.setNote(66),
                'q' => self.setNote(68),
                's' => self.setNote(70),
                else => {},
            }
        }

        _ = c.printf("\nGoodbye!\n");
    }

    fn moveUp(self: *Screen) void {
        switch (self.mode) {
            .pattern => { if (self.cursor_row > 0) self.cursor_row -= 1; },
            .song => { if (self.song_cursor > 0) self.song_cursor -= 1; },
            .instrument => { if (self.inst_cursor > 0) self.inst_cursor -= 1; },
            .mixer => { if (self.mixer_cursor > 0) self.mixer_cursor -= 1; },
        }
    }

    fn moveDown(self: *Screen) void {
        switch (self.mode) {
            .pattern => { if (self.cursor_row < self.sequencer.current_pattern.rows - 1) self.cursor_row += 1; },
            .song => { if (self.song_cursor < self.sequencer.song.length - 1) self.song_cursor += 1; },
            .instrument => { self.inst_cursor += 1; },
            .mixer => { if (self.mixer_cursor < 7) self.mixer_cursor += 1; },
        }
    }

    fn moveLeft(self: *Screen) void {
        switch (self.mode) {
            .pattern => { if (self.cursor_channel > 0) self.cursor_channel -= 1; },
            .song => {},
            .instrument => {},
            .mixer => {},
        }
    }

    fn moveRight(self: *Screen) void {
        switch (self.mode) {
            .pattern => { if (self.cursor_channel < self.sequencer.current_pattern.channels - 1) self.cursor_channel += 1; },
            .song => {},
            .instrument => {},
            .mixer => {},
        }
    }

    fn draw(self: *Screen) !void {
        _ = self;
    }

    fn drawPattern(self: *Screen) !void {
        _ = self;
    }

    fn drawSong(self: *Screen) !void {
        _ = self;
    }

    fn drawInstrument(_: *Screen) !void {
    }

    fn drawMixer(self: *Screen) !void {
        _ = self;
    }

    fn drawHelp(_: *Screen) !void {
    }

    fn setNote(self: *Screen, note: u8) void {
        const pat = self.sequencer.current_pattern;
        var locks: synth.ParameterLock = .{};

        locks.volume = 0.8;
        locks.pan = 0.0;

        pat.setNote(self.cursor_row, self.cursor_channel, tracker.NoteEvent{
            .note = note,
            .instrument = @intCast(self.cursor_channel),
            .volume = 64,
            .effect = 0,
            .effect_param = 0,
            .locks = locks,
        });

        self.engine.triggerNote(note, 100);

        if (self.cursor_row < pat.rows - 1) {
            self.cursor_row += 1;
        }
    }

    fn clearNote(self: *Screen) void {
        self.sequencer.current_pattern.setNote(self.cursor_row, self.cursor_channel, null);
    }

    fn handleDigit(self: *Screen, digit: u8) void {
        switch (self.mode) {
            .song => {
                self.sequencer.song.setSlot(self.song_cursor, digit, 0);
            },
            .mixer => {
                if (digit >= 1 and digit <= 8) {
                    self.engine.mixer.toggleMute(digit - 1);
                }
            },
            else => {},
        }
    }

    fn saveFile(self: *Screen) void {
        self.sequencer.saveToFile("gridtracker.song") catch |err| {
            std.debug.print("Save failed: {any}\n", .{err});
        };
    }

    fn loadFile(self: *Screen) void {
        self.sequencer.loadFromFile("gridtracker.song") catch |err| {
            std.debug.print("Load failed: {any}\n", .{err});
        };
    }

    fn clonePattern(self: *Screen) void {
        const current = self.sequencer.current_pattern_index;
        if (current < 255) {
            const src = self.sequencer.bank.getPattern(current).?;
            const dst = self.sequencer.bank.getPattern(current + 1).?;
            for (0..src.rows) |r| {
                for (0..src.channels) |ch| {
                    dst.data[r].notes[ch] = src.data[r].notes[ch];
                }
            }
            self.sequencer.setPattern(current + 1);
        }
    }

    fn prevPattern(self: *Screen) void {
        if (self.sequencer.current_pattern_index > 0) {
            self.sequencer.setPattern(self.sequencer.current_pattern_index - 1);
        }
    }

    fn nextPattern(self: *Screen) void {
        if (self.sequencer.current_pattern_index < 255) {
            self.sequencer.setPattern(self.sequencer.current_pattern_index + 1);
        }
    }

    fn toggleSongMode(self: *Screen) void {
        self.sequencer.song_mode = !self.sequencer.song_mode;
    }
};
