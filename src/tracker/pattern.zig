const std = @import("std");
const synth = @import("../synth/voice.zig");

pub const MAX_PATTERNS = 256;
pub const MAX_CHANNELS = 8;
pub const DEFAULT_ROWS = 64;
pub const MAX_ROWS = 256;
pub const MAX_BANKS = 16;

pub const FILE_MAGIC = "GTRK";
pub const FILE_VERSION: u8 = 3;

fn writeIntLe(writer: *std.Io.Writer, comptime T: type, value: T) !void {
    var buf: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &buf, value, .little);
    try writer.writeAll(&buf);
}

fn readIntLe(reader: *std.Io.Reader, comptime T: type) !T {
    return std.mem.readInt(T, try reader.takeArray(@sizeOf(T)), .little);
}

fn writeF32Le(writer: *std.Io.Writer, value: f32) !void {
    try writeIntLe(writer, u32, @bitCast(value));
}

fn readF32Le(reader: *std.Io.Reader) !f32 {
    return @bitCast(try readIntLe(reader, u32));
}

fn writeOptF32Le(writer: *std.Io.Writer, value: ?f32) !void {
    try writer.writeByte(if (value != null) 1 else 0);
    if (value) |v| try writeF32Le(writer, v);
}

fn readOptF32Le(reader: *std.Io.Reader) !?f32 {
    if ((try reader.takeByte()) != 0) {
        return try readF32Le(reader);
    }
    return null;
}

pub const NoteEvent = struct {
    note: u8, // MIDI note number (0 = note off if triggered)
    instrument: u8,
    volume: u8, // 0-64
    effect: u8,
    effect_param: u8,
    locks: synth.ParameterLock,
};

pub const Row = struct {
    notes: []?NoteEvent,
};

pub const Pattern = struct {
    allocator: std.mem.Allocator,
    rows: u32,
    channels: u32,
    data: []Row,
    name: [16]u8,

    pub fn init(allocator: std.mem.Allocator, rows: u32, channels: u32, name: []const u8) !Pattern {
        const data = try allocator.alloc(Row, rows);
        for (data) |*row| {
            row.notes = try allocator.alloc(?NoteEvent, channels);
            for (row.notes) |*note| {
                note.* = null;
            }
        }

        var pat = Pattern{
            .allocator = allocator,
            .rows = rows,
            .channels = channels,
            .data = data,
            .name = undefined,
        };
        @memset(&pat.name, 0);
        @memcpy(pat.name[0..@min(name.len, 16)], name[0..@min(name.len, 16)]);
        return pat;
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

    pub fn clear(self: *Pattern) void {
        for (self.data) |*row| {
            for (row.notes) |*note| {
                note.* = null;
            }
        }
    }

    pub fn clone(self: *const Pattern, allocator: std.mem.Allocator) !Pattern {
        var new = try Pattern.init(allocator, self.rows, self.channels, &self.name);
        for (0..self.rows) |r| {
            for (0..self.channels) |c| {
                new.data[r].notes[c] = self.data[r].notes[c];
            }
        }
        return new;
    }

    pub fn serialize(self: *const Pattern, writer: *std.Io.Writer) !void {
        try writeIntLe(writer, u32, self.rows);
        try writeIntLe(writer, u32, self.channels);
        try writer.writeAll(&self.name);
        for (0..self.rows) |r| {
            for (0..self.channels) |c| {
                if (self.data[r].notes[c]) |note| {
                    try writer.writeByte(1);
                    try writer.writeByte(note.note);
                    try writer.writeByte(note.instrument);
                    try writer.writeByte(note.volume);
                    try writer.writeByte(note.effect);
                    try writer.writeByte(note.effect_param);
                    // Serialize locks (all nine parameters)
                    try writeOptF32Le(writer, note.locks.pitch_bend);
                    try writeOptF32Le(writer, note.locks.filter_cutoff);
                    try writeOptF32Le(writer, note.locks.filter_resonance);
                    try writeOptF32Le(writer, note.locks.volume);
                    try writeOptF32Le(writer, note.locks.pan);
                    try writer.writeByte(if (note.locks.waveform != null) 1 else 0);
                    if (note.locks.waveform) |w| try writer.writeByte(@intFromEnum(w));
                    try writeOptF32Le(writer, note.locks.duty_cycle);
                    try writeOptF32Le(writer, note.locks.detune);
                    try writeOptF32Le(writer, note.locks.portamento);
                } else {
                    try writer.writeByte(0);
                }
            }
        }
    }

    pub fn deserialize(allocator: std.mem.Allocator, reader: *std.Io.Reader) !Pattern {
        const rows = try readIntLe(reader, u32);
        const channels = try readIntLe(reader, u32);
        if (rows == 0 or rows > MAX_ROWS) return error.InvalidFormat;
        if (channels == 0 or channels > MAX_CHANNELS) return error.InvalidFormat;
        var name: [16]u8 = undefined;
        try reader.readSliceAll(&name);
        var pat = try Pattern.init(allocator, rows, channels, &name);
        errdefer pat.deinit();
        for (0..rows) |r| {
            for (0..channels) |c| {
                const has_note = try reader.takeByte();
                if (has_note != 0) {
                    var note: NoteEvent = .{
                        .note = try reader.takeByte(),
                        .instrument = try reader.takeByte(),
                        .volume = try reader.takeByte(),
                        .effect = try reader.takeByte(),
                        .effect_param = try reader.takeByte(),
                        .locks = .{},
                    };
                    // Deserialize locks
                    note.locks.pitch_bend = try readOptF32Le(reader);
                    note.locks.filter_cutoff = try readOptF32Le(reader);
                    note.locks.filter_resonance = try readOptF32Le(reader);
                    note.locks.volume = try readOptF32Le(reader);
                    note.locks.pan = try readOptF32Le(reader);
                    if ((try reader.takeByte()) != 0) {
                        note.locks.waveform = @enumFromInt(try reader.takeByte());
                    }
                    note.locks.duty_cycle = try readOptF32Le(reader);
                    note.locks.detune = try readOptF32Le(reader);
                    note.locks.portamento = try readOptF32Le(reader);
                    pat.data[r].notes[c] = note;
                }
            }
        }
        return pat;
    }
};

pub const Bank = struct {
    allocator: std.mem.Allocator,
    patterns: []Pattern,
    active_count: u32,

    pub fn init(allocator: std.mem.Allocator) !Bank {
        const patterns = try allocator.alloc(Pattern, MAX_PATTERNS);
        for (0..MAX_PATTERNS) |i| {
            patterns[i] = try Pattern.init(allocator, DEFAULT_ROWS, MAX_CHANNELS, "UNTITLED");
        }
        return Bank{
            .allocator = allocator,
            .patterns = patterns,
            .active_count = MAX_PATTERNS,
        };
    }

    pub fn deinit(self: *Bank) void {
        for (self.patterns) |*pat| {
            pat.deinit();
        }
        self.allocator.free(self.patterns);
    }

    pub fn getPattern(self: *Bank, index: u32) ?*Pattern {
        if (index < self.active_count) return &self.patterns[index];
        return null;
    }
};

pub const SongSlot = struct {
    pattern_index: u8, // 0-255, 0xFF = empty/end
    transpose: i8,
};

pub const Song = struct {
    allocator: std.mem.Allocator,
    slots: []SongSlot,
    length: u32,
    loop_point: u32,

    pub fn init(allocator: std.mem.Allocator, length: u32) !Song {
        const slots = try allocator.alloc(SongSlot, length);
        for (slots) |*slot| {
            slot.pattern_index = 0xFF;
            slot.transpose = 0;
        }
        return Song{
            .allocator = allocator,
            .slots = slots,
            .length = length,
            .loop_point = 0,
        };
    }

    pub fn deinit(self: *Song) void {
        self.allocator.free(self.slots);
    }

    pub fn setSlot(self: *Song, pos: u32, pattern_index: u8, transpose: i8) void {
        if (pos < self.length) {
            self.slots[pos].pattern_index = pattern_index;
            self.slots[pos].transpose = transpose;
        }
    }

    pub fn getSlot(self: *Song, pos: u32) ?SongSlot {
        if (pos < self.length) return self.slots[pos];
        return null;
    }

    pub fn serialize(self: *const Song, writer: *std.Io.Writer) !void {
        try writeIntLe(writer, u32, self.length);
        try writeIntLe(writer, u32, self.loop_point);
        for (self.slots) |slot| {
            try writer.writeByte(slot.pattern_index);
            try writer.writeByte(@bitCast(slot.transpose));
        }
    }

    pub fn deserialize(allocator: std.mem.Allocator, reader: *std.Io.Reader) !Song {
        const length = try readIntLe(reader, u32);
        const loop_point = try readIntLe(reader, u32);
        if (length == 0 or length > MAX_PATTERNS) return error.InvalidFormat;
        if (loop_point >= length) return error.InvalidFormat;
        var song = try Song.init(allocator, length);
        errdefer song.deinit();
        song.loop_point = loop_point;
        for (0..length) |i| {
            song.slots[i].pattern_index = try reader.takeByte();
            song.slots[i].transpose = @bitCast(try reader.takeByte());
        }
        return song;
    }
};

pub const Sequencer = struct {
    allocator: std.mem.Allocator,
    bank: Bank,
    song: Song,
    current_pattern: *Pattern,
    current_pattern_index: u32,
    current_row: u32,
    is_playing: bool,
    bpm: f32,
    sample_rate: u32,
    samples_per_row: u32,
    sample_counter: u32,
    song_mode: bool,
    song_position: u32,
    song_looping: bool,
    row_notes: [MAX_CHANNELS]NoteEvent,

    pub fn init(allocator: std.mem.Allocator, sample_rate: u32) !Sequencer {
        var seq = Sequencer{
            .allocator = allocator,
            .bank = try Bank.init(allocator),
            .song = try Song.init(allocator, 256),
            .current_pattern = undefined,
            .current_pattern_index = 0,
            .current_row = 0,
            .is_playing = false,
            .bpm = 125.0,
            .sample_rate = sample_rate,
            .samples_per_row = 0,
            .sample_counter = 0,
            .song_mode = false,
            .song_position = 0,
            .song_looping = true,
            .row_notes = undefined,
        };
        seq.current_pattern = seq.bank.getPattern(0).?;
        seq.updateTiming(sample_rate);
        return seq;
    }

    pub fn deinit(self: *Sequencer) void {
        self.song.deinit();
        self.bank.deinit();
    }

    pub fn play(self: *Sequencer) void {
        self.is_playing = true;
        self.current_row = 0;
        self.sample_counter = 0;
        self.song_position = 0;
        // In song mode, start from the pattern in the first song slot
        if (self.song_mode) {
            if (self.song.getSlot(0)) |slot| {
                if (slot.pattern_index != 0xFF) {
                    self.setPattern(slot.pattern_index);
                }
            }
        }
        self.updateTiming(self.sample_rate);
    }

    pub fn stop(self: *Sequencer) void {
        self.is_playing = false;
    }

    pub fn setPattern(self: *Sequencer, index: u32) void {
        if (self.bank.getPattern(index)) |pat| {
            self.current_pattern = pat;
            self.current_pattern_index = index;
            self.current_row = 0;
        }
    }

    pub fn updateTiming(self: *Sequencer, sample_rate: u32) void {
        const seconds_per_row = 60.0 / (self.bpm * 4.0);
        self.samples_per_row = @intFromFloat(seconds_per_row * @as(f32, @floatFromInt(sample_rate)));
    }

    pub fn setBpm(self: *Sequencer, bpm: f32) void {
        self.bpm = std.math.clamp(bpm, 20.0, 999.0);
        self.updateTiming(self.sample_rate);
    }

    pub fn tick(self: *Sequencer) ?[]const NoteEvent {
        if (!self.is_playing) return null;

        self.sample_counter += 1;
        if (self.sample_counter >= self.samples_per_row) {
            self.sample_counter = 0;
            const row = self.current_row;
            self.current_row += 1;

            // Collect active notes for this row
            var count: usize = 0;
            for (0..self.current_pattern.channels) |ch| {
                if (self.current_pattern.getNote(row, @intCast(ch))) |note| {
                    self.row_notes[count] = note;
                    count += 1;
                }
            }

            // Advance pattern
            if (self.current_row >= self.current_pattern.rows) {
                self.current_row = 0;
                if (self.song_mode) {
                    self.song_position += 1;
                    if (self.song_position >= self.song.length) {
                        if (self.song_looping) {
                            self.song_position = self.song.loop_point;
                        } else {
                            self.is_playing = false;
                            return null;
                        }
                    }
                    if (self.song.getSlot(self.song_position)) |slot| {
                        if (slot.pattern_index != 0xFF) {
                            self.setPattern(slot.pattern_index);
                        }
                    }
                }
            }

            if (count > 0) {
                return self.row_notes[0..count];
            }
        }
        return null;
    }

    pub fn serialize(self: *const Sequencer, writer: *std.Io.Writer) !void {
        try writer.writeAll(FILE_MAGIC);
        try writer.writeByte(FILE_VERSION);
        try writeF32Le(writer, self.bpm);
        try self.song.serialize(writer);
        try writeIntLe(writer, u32, self.bank.active_count);
        for (0..self.bank.active_count) |i| {
            try self.bank.patterns[i].serialize(writer);
        }
    }

    pub fn deserialize(self: *Sequencer, reader: *std.Io.Reader) !void {
        var magic: [4]u8 = undefined;
        try reader.readSliceAll(&magic);
        if (!std.mem.eql(u8, &magic, FILE_MAGIC)) return error.InvalidFormat;

        const version = try reader.takeByte();
        if (version != FILE_VERSION) return error.UnsupportedVersion;

        self.bpm = try readF32Le(reader);
        self.updateTiming(self.sample_rate);

        // Replace song
        const song = try Song.deserialize(self.allocator, reader);
        self.song.deinit();
        self.song = song;

        // Replace patterns
        const pattern_count = try readIntLe(reader, u32);
        if (pattern_count == 0 or pattern_count > MAX_PATTERNS) return error.InvalidFormat;
        for (0..pattern_count) |i| {
            const pat = try Pattern.deserialize(self.allocator, reader);
            self.bank.patterns[i].deinit();
            self.bank.patterns[i] = pat;
        }
        // Clear any patterns beyond the loaded set
        for (pattern_count..MAX_PATTERNS) |i| {
            self.bank.patterns[i].clear();
        }
        self.bank.active_count = pattern_count;

        // Re-anchor the current pattern pointer into the bank
        if (self.current_pattern_index >= pattern_count) {
            self.current_pattern_index = 0;
        }
        self.current_pattern = self.bank.getPattern(self.current_pattern_index).?;
        self.current_row = 0;
        self.sample_counter = 0;
        self.song_position = 0;
    }

    pub fn saveToFile(self: *Sequencer, io: std.Io, path: []const u8) !void {
        const file = try std.Io.Dir.cwd().createFile(io, path, .{});
        defer file.close(io);

        var buf: [4096]u8 = undefined;
        var file_writer = file.writer(io, &buf);
        try self.serialize(&file_writer.interface);
        try file_writer.interface.flush();
    }

    pub fn loadFromFile(self: *Sequencer, io: std.Io, path: []const u8) !void {
        const file = try std.Io.Dir.cwd().openFile(io, path, .{});
        defer file.close(io);

        var buf: [4096]u8 = undefined;
        var file_reader = file.reader(io, &buf);
        try self.deserialize(&file_reader.interface);
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

fn testNote(note: u8, instrument: u8, volume: u8) NoteEvent {
    return .{
        .note = note,
        .instrument = instrument,
        .volume = volume,
        .effect = 0,
        .effect_param = 0,
        .locks = .{},
    };
}

test "pattern set/get/clear note" {
    const allocator = testing.allocator;
    var pat = try Pattern.init(allocator, 16, 4, "BASS");
    defer pat.deinit();

    try testing.expectEqualStrings("BASS", std.mem.sliceTo(&pat.name, 0));
    try testing.expect(pat.getNote(0, 0) == null);

    const ev = testNote(60, 1, 64);
    pat.setNote(3, 2, ev);
    const got = pat.getNote(3, 2).?;
    try testing.expectEqual(@as(u8, 60), got.note);
    try testing.expectEqual(@as(u8, 1), got.instrument);
    try testing.expectEqual(@as(u8, 64), got.volume);

    // Out-of-bounds access is ignored safely
    pat.setNote(99, 99, ev);
    try testing.expect(pat.getNote(99, 99) == null);
    try testing.expect(pat.getNote(16, 0) == null);
    try testing.expect(pat.getNote(0, 4) == null);

    pat.setNote(3, 2, null);
    try testing.expect(pat.getNote(3, 2) == null);

    pat.setNote(0, 0, ev);
    pat.clear();
    try testing.expect(pat.getNote(0, 0) == null);
}

test "pattern name truncation" {
    const allocator = testing.allocator;
    var pat = try Pattern.init(allocator, 4, 2, "THIS_NAME_IS_WAY_TOO_LONG");
    defer pat.deinit();
    try testing.expectEqual(@as(usize, 16), std.mem.sliceTo(&pat.name, 0).len);
}

test "pattern clone is deep and independent" {
    const allocator = testing.allocator;
    var pat = try Pattern.init(allocator, 8, 2, "LEAD");
    defer pat.deinit();
    pat.setNote(1, 1, testNote(67, 0, 50));

    var copy = try pat.clone(allocator);
    defer copy.deinit();

    try testing.expectEqual(pat.rows, copy.rows);
    try testing.expectEqual(pat.channels, copy.channels);
    try testing.expectEqual(@as(u8, 67), copy.getNote(1, 1).?.note);

    // Mutating the clone does not affect the original
    copy.setNote(1, 1, testNote(69, 0, 50));
    try testing.expectEqual(@as(u8, 67), pat.getNote(1, 1).?.note);
}

test "parameter locks store and retrieve" {
    const allocator = testing.allocator;
    var pat = try Pattern.init(allocator, 8, 2, "LOCKS");
    defer pat.deinit();

    var ev = testNote(60, 0, 64);
    ev.locks.volume = 0.5;
    ev.locks.pan = -0.25;
    ev.locks.waveform = .square;
    ev.locks.filter_cutoff = 0.75;
    ev.locks.duty_cycle = 0.1;
    pat.setNote(2, 1, ev);

    const got = pat.getNote(2, 1).?;
    try testing.expectEqual(@as(f32, 0.5), got.locks.volume.?);
    try testing.expectEqual(@as(f32, -0.25), got.locks.pan.?);
    try testing.expectEqual(synth.Waveform.square, got.locks.waveform.?);
    try testing.expectEqual(@as(f32, 0.75), got.locks.filter_cutoff.?);
    try testing.expectEqual(@as(f32, 0.1), got.locks.duty_cycle.?);
    try testing.expect(got.locks.pitch_bend == null);
    try testing.expect(got.locks.portamento == null);
}

test "bank pattern access bounds" {
    const allocator = testing.allocator;
    var bank = try Bank.init(allocator);
    defer bank.deinit();

    try testing.expectEqual(MAX_PATTERNS, bank.active_count);
    try testing.expect(bank.getPattern(0) != null);
    try testing.expect(bank.getPattern(MAX_PATTERNS - 1) != null);
    try testing.expect(bank.getPattern(MAX_PATTERNS) == null);
}

test "song slots set/get with bounds" {
    const allocator = testing.allocator;
    var song = try Song.init(allocator, 8);
    defer song.deinit();

    // Slots default to empty
    try testing.expectEqual(@as(u8, 0xFF), song.getSlot(0).?.pattern_index);

    song.setSlot(0, 3, -2);
    const slot = song.getSlot(0).?;
    try testing.expectEqual(@as(u8, 3), slot.pattern_index);
    try testing.expectEqual(@as(i8, -2), slot.transpose);

    song.setSlot(99, 1, 0); // out of bounds: ignored
    try testing.expect(song.getSlot(8) == null);
}

fn makePlayingSequencer(allocator: std.mem.Allocator) !Sequencer {
    var seq = try Sequencer.init(allocator, 48000);
    seq.play();
    seq.samples_per_row = 2; // shrink row duration for fast tests
    return seq;
}

test "sequencer step advance and note trigger" {
    const allocator = testing.allocator;
    var seq = try makePlayingSequencer(allocator);
    defer seq.deinit();

    seq.current_pattern.setNote(0, 0, testNote(60, 0, 64));
    seq.current_pattern.setNote(0, 3, testNote(64, 3, 64));

    // First tick: counter 1 < 2, nothing yet
    try testing.expect(seq.tick() == null);
    // Second tick: row 0 fires both notes
    const notes = seq.tick().?;
    try testing.expectEqual(@as(usize, 2), notes.len);
    try testing.expectEqual(@as(u8, 60), notes[0].note);
    try testing.expectEqual(@as(u8, 64), notes[1].note);
    try testing.expectEqual(@as(u32, 1), seq.current_row);
}

test "sequencer wraps at pattern end" {
    const allocator = testing.allocator;
    var seq = try makePlayingSequencer(allocator);
    defer seq.deinit();

    seq.current_row = seq.current_pattern.rows - 1;
    _ = seq.tick();
    _ = seq.tick(); // this one crosses the boundary
    try testing.expectEqual(@as(u32, 0), seq.current_row);
    try testing.expect(seq.is_playing);
}

test "sequencer pattern bank switching" {
    const allocator = testing.allocator;
    var seq = try Sequencer.init(allocator, 48000);
    defer seq.deinit();

    seq.setPattern(5);
    try testing.expectEqual(@as(u32, 5), seq.current_pattern_index);
    try testing.expectEqual(@as(u32, 0), seq.current_row);

    seq.setPattern(9999); // out of range: no change
    try testing.expectEqual(@as(u32, 5), seq.current_pattern_index);
}

test "sequencer song mode advances through slots" {
    const allocator = testing.allocator;
    var seq = try makePlayingSequencer(allocator);
    defer seq.deinit();

    seq.song.setSlot(0, 0, 0);
    seq.song.setSlot(1, 3, 0);
    seq.song_mode = true;
    seq.setPattern(0);

    // Walk to the end of pattern 0
    seq.current_row = seq.current_pattern.rows - 1;
    _ = seq.tick();
    _ = seq.tick();

    try testing.expectEqual(@as(u32, 1), seq.song_position);
    try testing.expectEqual(@as(u32, 3), seq.current_pattern_index);
    try testing.expectEqual(@as(u32, 0), seq.current_row);
}

test "sequencer song mode play loads first slot pattern" {
    const allocator = testing.allocator;
    var seq = try Sequencer.init(allocator, 48000);
    defer seq.deinit();

    seq.song.setSlot(0, 4, 0);
    seq.song_mode = true;
    seq.setPattern(9);
    seq.play();

    // Play must start from the pattern in song slot 0, not the selected one
    try testing.expectEqual(@as(u32, 4), seq.current_pattern_index);
}

test "sequencer song mode stops at song end when not looping" {
    const allocator = testing.allocator;
    var seq = try makePlayingSequencer(allocator);
    defer seq.deinit();

    seq.song_mode = true;
    seq.song_looping = false;
    seq.song_position = seq.song.length - 1;
    seq.current_row = seq.current_pattern.rows - 1;

    _ = seq.tick();
    try testing.expect(seq.tick() == null);
    try testing.expect(!seq.is_playing);
}

test "sequencer bpm clamp and timing" {
    const allocator = testing.allocator;
    var seq = try Sequencer.init(allocator, 48000);
    defer seq.deinit();

    seq.setBpm(120);
    try testing.expectEqual(@as(f32, 120.0), seq.bpm);
    // 120 BPM => 60/(120*4) = 0.125s per row => 6000 samples @48k
    try testing.expectEqual(@as(u32, 6000), seq.samples_per_row);

    seq.setBpm(1);
    try testing.expectEqual(@as(f32, 20.0), seq.bpm);
    seq.setBpm(5000);
    try testing.expectEqual(@as(f32, 999.0), seq.bpm);
}

fn expectPatternsEqual(a: *const Pattern, b: *const Pattern) !void {
    try testing.expectEqual(a.rows, b.rows);
    try testing.expectEqual(a.channels, b.channels);
    try testing.expectEqualSlices(u8, &a.name, &b.name);
    for (0..a.rows) |r| {
        for (0..a.channels) |c| {
            const na = a.data[r].notes[c];
            const nb = b.data[r].notes[c];
            if (na == null or nb == null) {
                try testing.expect(na == null and nb == null);
                continue;
            }
            const ea = na.?;
            const eb = nb.?;
            try testing.expectEqual(ea.note, eb.note);
            try testing.expectEqual(ea.instrument, eb.instrument);
            try testing.expectEqual(ea.volume, eb.volume);
            try testing.expectEqual(ea.effect, eb.effect);
            try testing.expectEqual(ea.effect_param, eb.effect_param);
            try testing.expectEqual(ea.locks.pitch_bend, eb.locks.pitch_bend);
            try testing.expectEqual(ea.locks.filter_cutoff, eb.locks.filter_cutoff);
            try testing.expectEqual(ea.locks.filter_resonance, eb.locks.filter_resonance);
            try testing.expectEqual(ea.locks.volume, eb.locks.volume);
            try testing.expectEqual(ea.locks.pan, eb.locks.pan);
            try testing.expectEqual(ea.locks.waveform, eb.locks.waveform);
            try testing.expectEqual(ea.locks.duty_cycle, eb.locks.duty_cycle);
            try testing.expectEqual(ea.locks.detune, eb.locks.detune);
            try testing.expectEqual(ea.locks.portamento, eb.locks.portamento);
        }
    }
}

test "pattern serialize/deserialize round-trip in memory" {
    const allocator = testing.allocator;
    var pat = try Pattern.init(allocator, 16, 4, "ROUNDTRIP");
    defer pat.deinit();

    var ev = testNote(48, 2, 40);
    ev.effect = 7;
    ev.effect_param = 0xAB;
    ev.locks.volume = 0.33;
    ev.locks.pan = 0.9;
    ev.locks.waveform = .sawtooth;
    ev.locks.detune = -12.5;
    ev.locks.portamento = 0.05;
    pat.setNote(0, 0, ev);
    pat.setNote(15, 3, testNote(72, 1, 64));

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();
    try pat.serialize(&aw.writer);
    const bytes = aw.written();

    var reader: std.Io.Reader = .fixed(bytes);
    var loaded = try Pattern.deserialize(allocator, &reader);
    defer loaded.deinit();

    try expectPatternsEqual(&pat, &loaded);
}

test "pattern deserialize rejects bad dimensions" {
    const allocator = testing.allocator;
    var buf: [8]u8 = undefined;
    std.mem.writeInt(u32, buf[0..4], 99999, .little);
    std.mem.writeInt(u32, buf[4..8], 8, .little);
    var reader: std.Io.Reader = .fixed(&buf);
    try testing.expectError(error.InvalidFormat, Pattern.deserialize(allocator, &reader));
}

test "song serialize/deserialize round-trip in memory" {
    const allocator = testing.allocator;
    var song = try Song.init(allocator, 16);
    defer song.deinit();
    song.setSlot(0, 1, 0);
    song.setSlot(1, 4, -3);
    song.loop_point = 1;

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();
    try song.serialize(&aw.writer);

    var reader: std.Io.Reader = .fixed(aw.written());
    var loaded = try Song.deserialize(allocator, &reader);
    defer loaded.deinit();

    try testing.expectEqual(song.length, loaded.length);
    try testing.expectEqual(@as(u32, 1), loaded.loop_point);
    try testing.expectEqual(@as(u8, 1), loaded.getSlot(0).?.pattern_index);
    try testing.expectEqual(@as(u8, 4), loaded.getSlot(1).?.pattern_index);
    try testing.expectEqual(@as(i8, -3), loaded.getSlot(1).?.transpose);
    try testing.expectEqual(@as(u8, 0xFF), loaded.getSlot(2).?.pattern_index);
}

test "sequencer save/load file round-trip" {
    const allocator = testing.allocator;
    const io = testing.io;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    // Build a sequencer with content worth keeping
    var seq = try Sequencer.init(allocator, 48000);
    defer seq.deinit();
    seq.setBpm(140);

    var ev = testNote(36, 1, 64);
    ev.locks.volume = 0.6;
    ev.locks.waveform = .triangle;
    ev.locks.filter_resonance = 0.4;
    seq.bank.getPattern(0).?.setNote(0, 0, ev);
    seq.bank.getPattern(2).?.setNote(7, 5, testNote(51, 2, 48));
    seq.song.setSlot(0, 0, 0);
    seq.song.setSlot(1, 2, 1);
    seq.song.loop_point = 1;
    seq.bank.active_count = 4;

    const path = "roundtrip.gtrk";
    {
        const file = try tmp.dir.createFile(io, path, .{});
        defer file.close(io);
        var buf: [4096]u8 = undefined;
        var fw = file.writer(io, &buf);
        try seq.serialize(&fw.interface);
        try fw.interface.flush();
    }

    // Load into a fresh sequencer and compare
    var loaded = try Sequencer.init(allocator, 48000);
    defer loaded.deinit();
    {
        const file = try tmp.dir.openFile(io, path, .{});
        defer file.close(io);
        var buf: [4096]u8 = undefined;
        var fr = file.reader(io, &buf);
        try loaded.deserialize(&fr.interface);
    }

    try testing.expectEqual(@as(f32, 140.0), loaded.bpm);
    try testing.expectEqual(@as(u32, 4), loaded.bank.active_count);
    try testing.expectEqual(@as(u32, 1), loaded.song.loop_point);
    try testing.expectEqual(@as(u8, 2), loaded.song.getSlot(1).?.pattern_index);
    try testing.expectEqual(@as(i8, 1), loaded.song.getSlot(1).?.transpose);
    try expectPatternsEqual(seq.bank.getPattern(0).?, loaded.bank.getPattern(0).?);
    try expectPatternsEqual(seq.bank.getPattern(2).?, loaded.bank.getPattern(2).?);

    // Patterns beyond the loaded set are cleared (accessed directly, since
    // getPattern is bounded by active_count)
    try testing.expect(loaded.bank.patterns[5].getNote(0, 0) == null);
}

test "sequencer load rejects bad magic and version" {
    const allocator = testing.allocator;
    const io = testing.io;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(io, .{ .sub_path = "bad.gtrk", .data = "NOPE\x03whatever" });

    var seq = try Sequencer.init(allocator, 48000);
    defer seq.deinit();
    try testing.expectError(error.InvalidFormat, blk: {
        const file = try tmp.dir.openFile(io, "bad.gtrk", .{});
        defer file.close(io);
        var buf: [256]u8 = undefined;
        var fr = file.reader(io, &buf);
        break :blk seq.deserialize(&fr.interface);
    });
}
