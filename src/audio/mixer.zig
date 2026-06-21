const std = @import("std");
const synth = @import("../synth/voice.zig");

pub const MAX_CHANNELS = 8;

pub const ChannelStrip = struct {
    volume: f32,    // 0.0 to 1.0
    pan: f32,       // -1.0 to 1.0
    mute: bool,
    solo: bool,
    name: [8]u8,

    pub fn init(name: []const u8) ChannelStrip {
        var strip: ChannelStrip = .{
            .volume = 0.8,
            .pan = 0.0,
            .mute = false,
            .solo = false,
            .name = undefined,
        };
        @memset(&strip.name, 0);
        @memcpy(strip.name[0..@min(name.len, 8)], name[0..@min(name.len, 8)]);
        return strip;
    }
};

pub const Mixer = struct {
    channels: [MAX_CHANNELS]ChannelStrip,
    master_volume: f32,
    any_solo: bool,

    pub fn init() Mixer {
        const names = [MAX_CHANNELS][]const u8{
            "CH1", "CH2", "CH3", "CH4",
            "CH5", "CH6", "CH7", "CH8",
        };
        var mixer = Mixer{
            .channels = undefined,
            .master_volume = 0.9,
            .any_solo = false,
        };
        for (0..MAX_CHANNELS) |i| {
            mixer.channels[i] = ChannelStrip.init(names[i]);
        }
        return mixer;
    }

    pub fn process(self: *Mixer, channel: usize, input: [2]f32) [2]f32 {
        if (channel >= MAX_CHANNELS) return .{ 0.0, 0.0 };
        const strip = &self.channels[channel];

        // Check mute/solo
        if (strip.mute) return .{ 0.0, 0.0 };
        if (self.any_solo and !strip.solo) return .{ 0.0, 0.0 };

        const pan = std.math.clamp(strip.pan, -1.0, 1.0);
        const vol = strip.volume * self.master_volume;

        const left = if (pan <= 0.0) 1.0 else 1.0 - pan;
        const right = if (pan >= 0.0) 1.0 else 1.0 + pan;

        return .{
            input[0] * vol * left,
            input[1] * vol * right,
        };
    }

    pub fn setVolume(self: *Mixer, channel: usize, volume: f32) void {
        if (channel < MAX_CHANNELS) {
            self.channels[channel].volume = std.math.clamp(volume, 0.0, 1.0);
        }
    }

    pub fn setPan(self: *Mixer, channel: usize, pan: f32) void {
        if (channel < MAX_CHANNELS) {
            self.channels[channel].pan = std.math.clamp(pan, -1.0, 1.0);
        }
    }

    pub fn toggleMute(self: *Mixer, channel: usize) void {
        if (channel < MAX_CHANNELS) {
            self.channels[channel].mute = !self.channels[channel].mute;
        }
    }

    pub fn toggleSolo(self: *Mixer, channel: usize) void {
        if (channel < MAX_CHANNELS) {
            self.channels[channel].solo = !self.channels[channel].solo;
            self.updateSoloState();
        }
    }

    fn updateSoloState(self: *Mixer) void {
        self.any_solo = false;
        for (self.channels) |ch| {
            if (ch.solo) {
                self.any_solo = true;
                break;
            }
        }
    }

    pub fn setMasterVolume(self: *Mixer, volume: f32) void {
        self.master_volume = std.math.clamp(volume, 0.0, 1.0);
    }
};
