const std = @import("std");
const c = @cImport({
    @cInclude("portmidi.h");
});

pub const Input = struct {
    allocator: std.mem.Allocator,
    stream: ?*c.PmStream,

    pub fn init(allocator: std.mem.Allocator) !Input {
        const err = c.Pm_Initialize();
        if (err != c.pmNoError) {
            std.debug.print("PortMidi init failed\n", .{});
            return error.PortMidiInitFailed;
        }

        // List available MIDI devices
        const device_count = c.Pm_CountDevices();
        std.debug.print("MIDI devices: {d}\n", .{device_count});

        var i: i32 = 0;
        while (i < device_count) : (i += 1) {
            const info = c.Pm_GetDeviceInfo(i);
            if (info) |dev| {
                std.debug.print("  [{d}] {s} (input: {d}, output: {d})\n", .{
                    i,
                    dev.*.name,
                    dev.*.input,
                    dev.*.output,
                });
            }
        }

        // Open default input device
        var stream: ?*c.PmStream = null;
        const open_err = c.Pm_OpenInput(&stream, c.Pm_GetDefaultInputDeviceID(), null, 256, null, null);
        if (open_err != c.pmNoError) {
            std.debug.print("PortMidi open input failed\n", .{});
            return error.PortMidiOpenFailed;
        }

        return Input{
            .allocator = allocator,
            .stream = stream,
        };
    }

    pub fn deinit(self: *Input) void {
        if (self.stream) |stream| {
            _ = c.Pm_Close(stream);
        }
        _ = c.Pm_Terminate();
    }

    pub fn poll(self: *Input) ?MidiEvent {
        if (self.stream) |stream| {
            if (c.Pm_Poll(stream) > 0) {
                var buffer: c.PmEvent = undefined;
                const count = c.Pm_Read(stream, &buffer, 1);
                if (count > 0) {
                    const status: u8 = @intCast(buffer.message & 0xFF);
                    const data1: u8 = @intCast((buffer.message >> 8) & 0xFF);
                    const data2: u8 = @intCast((buffer.message >> 16) & 0xFF);

                    return MidiEvent{
                        .status = status,
                        .data1 = data1,
                        .data2 = data2,
                        .timestamp = buffer.timestamp,
                    };
                }
            }
        }
        return null;
    }

    pub fn readEvents(self: *Input, events: []MidiEvent) usize {
        var count: usize = 0;
        while (count < events.len) {
            if (self.poll()) |event| {
                events[count] = event;
                count += 1;
            } else {
                break;
            }
        }
        return count;
    }
};

pub const MidiEvent = struct {
    status: u8,
    data1: u8,
    data2: u8,
    timestamp: c.PmTimestamp,

    pub fn isNoteOn(self: MidiEvent) bool {
        return (self.status & 0xF0) == 0x90 and self.data2 > 0;
    }

    pub fn isNoteOff(self: MidiEvent) bool {
        return (self.status & 0xF0) == 0x80 or ((self.status & 0xF0) == 0x90 and self.data2 == 0);
    }

    pub fn channel(self: MidiEvent) u4 {
        return @intCast(self.status & 0x0F);
    }

    pub fn note(self: MidiEvent) u8 {
        return self.data1;
    }

    pub fn velocity(self: MidiEvent) u8 {
        return self.data2;
    }
};
