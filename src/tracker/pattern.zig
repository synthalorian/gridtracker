const std = @import("std");

pub const Pattern = struct {
    allocator: std.mem.Allocator,
    rows: u32,
    channels: u32,
    data: []Row,
    current_row: u32,
    is_playing: bool,
    bpm: f32,
    samples_per_row: u32,
    sample_counter: u32,

    pub const Row = struct {
        notes: []?NoteEvent,
    };

    pub const NoteEvent = struct {
        note: u8, // MIDI note number
        instrument: u8,
        volume: u8,
        effect: u8,
        effect_param: u8,
    };

    pub fn init(allocator: std.mem.Allocator, rows: u32, channels: u32) !Pattern {
        var data = try allocator.alloc(Row, rows);
        for (data) |*row| {
            row.notes = try allocator.alloc(?NoteEvent, channels);
            for (row.notes) |*note| {
                note.* = null;
            }
        }

        return Pattern{
            .allocator = allocator,
            .rows = rows,
            .channels = channels,
            .data = data,
            .current_row = 0,
            .is_playing = false,
            .bpm = 125.0,
            .samples_per_row = 0,
            .sample_counter = 0,
        };
    }

    pub fn deinit(self: *Pattern) void {
        for (self.data) |row| {
            self.allocator.free(row.notes);
        }
        self.allocator.free(self.data);
    }

    pub fn setNote(self: *Pattern, row: u32, channel: u32, note: ?NoteEvent) void {
        if (row < self.rows and channel < self.channels) {
            self.data[row].notes[channel] = note;
        }
    }

    pub fn getNote(self: *Pattern, row: u32, channel: u32) ?NoteEvent {
        if (row < self.rows and channel < self.channels) {
            return self.data[row].notes[channel];
        }
        return null;
    }

    pub fn play(self: *Pattern) void {
        self.is_playing = true;
        self.current_row = 0;
        self.sample_counter = 0;
        self.updateTiming(48000);
    }

    pub fn stop(self: *Pattern) void {
        self.is_playing = false;
    }

    pub fn updateTiming(self: *Pattern, sample_rate: u32) void {
        // Calculate samples per row based on BPM
        // 4 rows per beat, 60 seconds per minute
        const seconds_per_row = 60.0 / (self.bpm * 4.0);
        self.samples_per_row = @intFromFloat(seconds_per_row * @as(f32, @floatFromInt(sample_rate)));
    }

    pub fn tick(self: *Pattern) ?[]const NoteEvent {
        if (!self.is_playing) return null;

        self.sample_counter += 1;
        if (self.sample_counter >= self.samples_per_row) {
            self.sample_counter = 0;
            const row = self.current_row;
            self.current_row = (self.current_row + 1) % self.rows;

            // Collect active notes for this row
            var active_notes: [8]NoteEvent = undefined;
            var count: usize = 0;
            for (self.data[row].notes, 0..) |maybe_note, ch| {
                if (maybe_note) |note| {
                    active_notes[count] = note;
                    active_notes[count].note = note.note;
                    count += 1;
                }
            }
            if (count > 0) {
                return active_notes[0..count];
            }
        }
        return null;
    }

    pub fn setBpm(self: *Pattern, bpm: f32) void {
        self.bpm = bpm;
    }
};
