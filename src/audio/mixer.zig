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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

test "mixer defaults pass signal with channel and master volume" {
    var mixer = Mixer.init();
    const out = mixer.process(0, .{ 1.0, 1.0 });
    // channel volume 0.8 * master 0.9, center pan
    try testing.expectApproxEqAbs(@as(f32, 0.72), out[0], 0.0001);
    try testing.expectApproxEqAbs(@as(f32, 0.72), out[1], 0.0001);
}

test "mixer per-channel volume" {
    var mixer = Mixer.init();
    mixer.setMasterVolume(1.0);
    mixer.setVolume(2, 0.5);
    const out = mixer.process(2, .{ 1.0, 1.0 });
    try testing.expectApproxEqAbs(@as(f32, 0.5), out[0], 0.0001);

    // Volume is clamped
    mixer.setVolume(2, 5.0);
    try testing.expectEqual(@as(f32, 1.0), mixer.channels[2].volume);
    mixer.setVolume(2, -1.0);
    try testing.expectEqual(@as(f32, 0.0), mixer.channels[2].volume);
}

test "mixer mute silences channel" {
    var mixer = Mixer.init();
    mixer.toggleMute(3);
    const out = mixer.process(3, .{ 1.0, 1.0 });
    try testing.expectEqual(@as(f32, 0.0), out[0]);
    try testing.expectEqual(@as(f32, 0.0), out[1]);

    // Other channels unaffected; unmute restores
    try testing.expect(mixer.process(0, .{ 1.0, 1.0 })[0] != 0.0);
    mixer.toggleMute(3);
    try testing.expect(mixer.process(3, .{ 1.0, 1.0 })[0] != 0.0);
}

test "mixer pan hard left and right" {
    var mixer = Mixer.init();
    mixer.setMasterVolume(1.0);
    mixer.setVolume(0, 1.0);

    mixer.setPan(0, -1.0);
    var out = mixer.process(0, .{ 1.0, 1.0 });
    try testing.expectEqual(@as(f32, 1.0), out[0]);
    try testing.expectEqual(@as(f32, 0.0), out[1]);

    mixer.setPan(0, 1.0);
    out = mixer.process(0, .{ 1.0, 1.0 });
    try testing.expectEqual(@as(f32, 0.0), out[0]);
    try testing.expectEqual(@as(f32, 1.0), out[1]);
}

test "mixer solo isolates channel" {
    var mixer = Mixer.init();
    mixer.toggleSolo(1);
    try testing.expect(mixer.any_solo);

    // Non-solo channels are silent
    try testing.expectEqual(@as(f32, 0.0), mixer.process(0, .{ 1.0, 1.0 })[0]);
    // Solo channel plays
    try testing.expect(mixer.process(1, .{ 1.0, 1.0 })[0] != 0.0);

    mixer.toggleSolo(1);
    try testing.expect(!mixer.any_solo);
    try testing.expect(mixer.process(0, .{ 1.0, 1.0 })[0] != 0.0);
}

test "mixer out-of-range channel is silent and safe" {
    var mixer = Mixer.init();
    const out = mixer.process(99, .{ 1.0, 1.0 });
    try testing.expectEqual(@as(f32, 0.0), out[0]);
    try testing.expectEqual(@as(f32, 0.0), out[1]);

    // Setters ignore out-of-range channels
    mixer.setVolume(99, 0.1);
    mixer.setPan(99, 1.0);
    mixer.toggleMute(99);
    mixer.toggleSolo(99);
    try testing.expect(!mixer.any_solo);
}

test "mixer init defaults" {
    const mixer = Mixer.init();
    try std.testing.expectEqual(@as(f32, 0.9), mixer.master_volume);
    try std.testing.expect(!mixer.any_solo);
    for (mixer.channels) |ch| {
        try std.testing.expectEqual(@as(f32, 0.8), ch.volume);
        try std.testing.expectEqual(@as(f32, 0.0), ch.pan);
        try std.testing.expect(!ch.mute);
        try std.testing.expect(!ch.solo);
    }
}

test "mixer process applies channel and master volume" {
    var mixer = Mixer.init();
    mixer.setVolume(0, 0.5);
    mixer.setMasterVolume(1.0);
    const out = mixer.process(0, .{ 1.0, 1.0 });
    try std.testing.expectEqual(@as(f32, 0.5), out[0]);
    try std.testing.expectEqual(@as(f32, 0.5), out[1]);
}

test "mixer solo silences non-solo channels" {
    var mixer = Mixer.init();
    mixer.toggleSolo(1);
    try std.testing.expect(mixer.any_solo);
    const soloed = mixer.process(1, .{ 1.0, 1.0 });
    try std.testing.expect(soloed[0] > 0.0);
    const other = mixer.process(0, .{ 1.0, 1.0 });
    try std.testing.expectEqual(@as(f32, 0.0), other[0]);
    // Un-solo restores everything
    mixer.toggleSolo(1);
    try std.testing.expect(!mixer.any_solo);
    const restored = mixer.process(0, .{ 1.0, 1.0 });
    try std.testing.expect(restored[0] > 0.0);
}

test "mixer pan attenuates opposite side" {
    var mixer = Mixer.init();
    mixer.setVolume(0, 1.0);
    mixer.setMasterVolume(1.0);
    mixer.setPan(0, -1.0); // hard left
    const left = mixer.process(0, .{ 1.0, 1.0 });
    try std.testing.expectEqual(@as(f32, 1.0), left[0]);
    try std.testing.expectEqual(@as(f32, 0.0), left[1]);

    mixer.setPan(0, 1.0); // hard right
    const right = mixer.process(0, .{ 1.0, 1.0 });
    try std.testing.expectEqual(@as(f32, 0.0), right[0]);
    try std.testing.expectEqual(@as(f32, 1.0), right[1]);
}

test "mixer volume and pan are clamped" {
    var mixer = Mixer.init();
    mixer.setVolume(0, 5.0);
    try std.testing.expectEqual(@as(f32, 1.0), mixer.channels[0].volume);
    mixer.setVolume(0, -2.0);
    try std.testing.expectEqual(@as(f32, 0.0), mixer.channels[0].volume);
    mixer.setPan(0, 99.0);
    try std.testing.expectEqual(@as(f32, 1.0), mixer.channels[0].pan);
    mixer.setMasterVolume(-1.0);
    try std.testing.expectEqual(@as(f32, 0.0), mixer.master_volume);
}

test "mixer out-of-range channel is safe" {
    var mixer = Mixer.init();
    const out = mixer.process(100, .{ 1.0, 1.0 });
    try std.testing.expectEqual(@as(f32, 0.0), out[0]);
    mixer.setVolume(100, 0.5); // must not crash or corrupt
    mixer.toggleMute(100);
    mixer.toggleSolo(100);
    try std.testing.expect(!mixer.any_solo);
}
