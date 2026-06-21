const std = @import("std");
const synth = @import("../synth/voice.zig");

pub const MAX_PATTERNS = 256;
pub const MAX_CHANNELS = 8;
pub const DEFAULT_ROWS = 64;
pub const MAX_ROWS = 256;
pub const MAX_BANKS = 16;

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

    pub fn serialize(self: *const Pattern, writer: anytype) !void {
        try writer.writeInt(u32, self.rows, .little);
        try writer.writeInt(u32, self.channels, .little);
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
                    // Serialize locks
                    try writer.writeByte(if (note.locks.pitch_bend != null) 1 else 0);
                    if (note.locks.pitch_bend) |v| try writer.writeAll(std.mem.asBytes(&v));
                    try writer.writeByte(if (note.locks.filter_cutoff != null) 1 else 0);
                    if (note.locks.filter_cutoff) |v| try writer.writeAll(std.mem.asBytes(&v));
                    try writer.writeByte(if (note.locks.filter_resonance != null) 1 else 0);
                    if (note.locks.filter_resonance) |v| try writer.writeAll(std.mem.asBytes(&v));
                    try writer.writeByte(if (note.locks.volume != null) 1 else 0);
                    if (note.locks.volume) |v| try writer.writeAll(std.mem.asBytes(&v));
                    try writer.writeByte(if (note.locks.pan != null) 1 else 0);
                    if (note.locks.pan) |v| try writer.writeAll(std.mem.asBytes(&v));
                    try writer.writeByte(if (note.locks.waveform != null) 1 else 0);
                    if (note.locks.waveform) |w| try writer.writeByte(@intFromEnum(w));
                    try writer.writeByte(if (note.locks.duty_cycle != null) 1 else 0);
                    if (note.locks.duty_cycle) |v| try writer.writeAll(std.mem.asBytes(&v));
                    try writer.writeByte(if (note.locks.detune != null) 1 else 0);
                    if (note.locks.detune) |v| try writer.writeAll(std.mem.asBytes(&v));
                } else {
                    try writer.writeByte(0);
                }
            }
        }
    }

    pub fn deserialize(allocator: std.mem.Allocator, reader: anytype) !Pattern {
        const rows = try reader.readInt(u32, .little);
        const channels = try reader.readInt(u32, .little);
        var name: [16]u8 = undefined;
        try reader.readNoEof(&name);
        var pat = try Pattern.init(allocator, rows, channels, &name);
        for (0..rows) |r| {
            for (0..channels) |c| {
                const has_note = try reader.readByte();
                if (has_note != 0) {
                    var note: NoteEvent = undefined;
                    note.note = try reader.readByte();
                    note.instrument = try reader.readByte();
                    note.volume = try reader.readByte();
                    note.effect = try reader.readByte();
                    note.effect_param = try reader.readByte();
                    // Deserialize locks
                    if ((try reader.readByte()) != 0) {
                        var buf: [4]u8 = undefined;
                        try reader.readNoEof(&buf);
                        note.locks.pitch_bend = @bitCast(buf);
                    }
                    if ((try reader.readByte()) != 0) {
                        var buf: [4]u8 = undefined;
                        try reader.readNoEof(&buf);
                        note.locks.filter_cutoff = @bitCast(buf);
                    }
                    if ((try reader.readByte()) != 0) {
                        var buf: [4]u8 = undefined;
                        try reader.readNoEof(&buf);
                        note.locks.filter_resonance = @bitCast(buf);
                    }
                    if ((try reader.readByte()) != 0) {
                        var buf: [4]u8 = undefined;
                        try reader.readNoEof(&buf);
                        note.locks.volume = @bitCast(buf);
                    }
                    if ((try reader.readByte()) != 0) {
                        var buf: [4]u8 = undefined;
                        try reader.readNoEof(&buf);
                        note.locks.pan = @bitCast(buf);
                    }
                    if ((try reader.readByte()) != 0) {
                        const w = try reader.readByte();
                        note.locks.waveform = @enumFromInt(w);
                    }
                    if ((try reader.readByte()) != 0) {
                        var buf: [4]u8 = undefined;
                        try reader.readNoEof(&buf);
                        note.locks.duty_cycle = @bitCast(buf);
                    }
                    if ((try reader.readByte()) != 0) {
                        var buf: [4]u8 = undefined;
                        try reader.readNoEof(&buf);
                        note.locks.detune = @bitCast(buf);
                    }
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

    pub fn serialize(self: *const Song, writer: anytype) !void {
        try writer.writeInt(u32, self.length, .little);
        try writer.writeInt(u32, self.loop_point, .little);
        for (self.slots) |slot| {
            try writer.writeByte(slot.pattern_index);
            try writer.writeByte(@bitCast(slot.transpose));
        }
    }

    pub fn deserialize(allocator: std.mem.Allocator, reader: anytype) !Song {
        const length = try reader.readInt(u32, .little);
        const loop_point = try reader.readInt(u32, .little);
        var song = try Song.init(allocator, length);
        song.loop_point = loop_point;
        for (0..length) |i| {
            song.slots[i].pattern_index = try reader.readByte();
            song.slots[i].transpose = @bitCast(try reader.readByte());
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
    samples_per_row: u32,
    sample_counter: u32,
    song_mode: bool,
    song_position: u32,
    song_looping: bool,

    pub fn init(allocator: std.mem.Allocator, _sample_rate: u32) !Sequencer {
        _ = _sample_rate;
        var bank = try Bank.init(allocator);
        const song = try Song.init(allocator, 256);
        return Sequencer{
            .allocator = allocator,
            .bank = bank,
            .song = song,
            .current_pattern = bank.getPattern(0).?,
            .current_pattern_index = 0,
            .current_row = 0,
            .is_playing = false,
            .bpm = 125.0,
            .samples_per_row = 0,
            .sample_counter = 0,
            .song_mode = false,
            .song_position = 0,
            .song_looping = true,
        };
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
        self.updateTiming(48000);
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
    }

    pub fn tick(self: *Sequencer) ?[]const NoteEvent {
        if (!self.is_playing) return null;

        self.sample_counter += 1;
        if (self.sample_counter >= self.samples_per_row) {
            self.sample_counter = 0;
            const row = self.current_row;
            self.current_row += 1;

            // Collect active notes for this row
            var active_notes: [MAX_CHANNELS]NoteEvent = undefined;
            var count: usize = 0;
            for (0..self.current_pattern.channels) |ch| {
                if (self.current_pattern.getNote(row, @intCast(ch))) |note| {
                    active_notes[count] = note;
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
                return active_notes[0..count];
            }
        }
        return null;
    }

    pub fn saveToFile(self: *Sequencer, path: []const u8) !void {
        const c = @cImport({
            @cInclude("stdio.h");
        });
        const file = c.fopen(path.ptr, "wb");
        if (file == null) return error.FileOpenFailed;
        defer _ = c.fclose(file);

        // Magic + version
        _ = c.fwrite("GTRK", 1, 4, file);
        _ = c.fputc(2, file);

        // Save BPM
        _ = c.fwrite(&self.bpm, 1, @sizeOf(f32), file);

        // Save song (simplified - just write song slots)
        for (0..self.song.length) |i| {
            _ = c.fwrite(&self.song.slots[i].pattern_index, 1, 1, file);
            _ = c.fwrite(&self.song.slots[i].transpose, 1, 1, file);
        }

        // Save number of patterns
        _ = c.fwrite(&self.bank.active_count, 1, @sizeOf(u32), file);

        // Save all patterns (simplified)
        for (0..self.bank.active_count) |i| {
            const pat = self.bank.patterns[i];
            _ = c.fwrite(&pat.rows, 1, @sizeOf(u32), file);
            _ = c.fwrite(&pat.channels, 1, @sizeOf(u32), file);
            for (0..pat.rows) |r| {
                for (0..pat.channels) |ch| {
                    if (pat.data[r].notes[ch]) |note| {
                        _ = c.fwrite(&note.note, 1, 1, file);
                        _ = c.fwrite(&note.instrument, 1, 1, file);
                        _ = c.fwrite(&note.volume, 1, 1, file);
                    } else {
                        var empty: u8 = 0xFF;
                        _ = c.fwrite(&empty, 1, 1, file);
                        _ = c.fwrite(&empty, 1, 1, file);
                        _ = c.fwrite(&empty, 1, 1, file);
                    }
                }
            }
        }
    }

    pub fn loadFromFile(self: *Sequencer, path: []const u8) !void {
        const c = @cImport({
            @cInclude("stdio.h");
        });
        const file = c.fopen(path.ptr, "rb");
        if (file == null) return error.FileOpenFailed;
        defer _ = c.fclose(file);

        var magic: [4]u8 = undefined;
        _ = c.fread(&magic, 1, 4, file);
        if (!std.mem.eql(u8, &magic, "GTRK")) return error.InvalidFormat;

        const version = c.fgetc(file);
        if (version != 2) return error.UnsupportedVersion;

        // Load BPM
        _ = c.fread(&self.bpm, 1, @sizeOf(f32), file);

        // Load song (simplified)
        for (0..self.song.length) |i| {
            _ = c.fread(&self.song.slots[i].pattern_index, 1, 1, file);
            _ = c.fread(&self.song.slots[i].transpose, 1, 1, file);
        }

        // Load number of patterns
        var active_count: u32 = 0;
        _ = c.fread(&active_count, 1, @sizeOf(u32), file);
        self.bank.active_count = active_count;

        // Load all patterns (simplified)
        for (0..active_count) |i| {
            var pat = &self.bank.patterns[i];
            _ = c.fread(&pat.rows, 1, @sizeOf(u32), file);
            _ = c.fread(&pat.channels, 1, @sizeOf(u32), file);
            for (0..pat.rows) |r| {
                for (0..pat.channels) |ch| {
                    var note_byte: u8 = 0xFF;
                    var inst_byte: u8 = 0xFF;
                    var vol_byte: u8 = 0xFF;
                    _ = c.fread(&note_byte, 1, 1, file);
                    _ = c.fread(&inst_byte, 1, 1, file);
                    _ = c.fread(&vol_byte, 1, 1, file);
                    if (note_byte != 0xFF) {
                        pat.data[r].notes[ch] = NoteEvent{
                            .note = note_byte,
                            .instrument = inst_byte,
                            .volume = vol_byte,
                            .effect = 0,
                            .effect_param = 0,
                            .locks = .{},
                        };
                    } else {
                        pat.data[r].notes[ch] = null;
                    }
                }
            }
        }
    }
};
