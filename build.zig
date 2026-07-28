const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "gridtracker",
        .root_module = mod,
    });

    // Link PortAudio for real-time audio
    mod.linkSystemLibrary("portaudio", .{});
    // Link PortMidi for MIDI input
    mod.linkSystemLibrary("portmidi", .{});
    // Link math for synthesis
    mod.link_libc = true;

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run GridTracker");
    run_step.dependOn(&run_cmd.step);

    // Unit tests for the pure-logic modules (wired in via src/tests.zig).
    // These run headless: no audio hardware, no MIDI devices and no
    // terminal are required.
    const test_step = b.step("test", "Run unit tests");

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const unit_test = b.addTest(.{
        .name = "gridtracker",
        .root_module = test_mod,
    });
    const run_test = b.addRunArtifact(unit_test);
    test_step.dependOn(&run_test.step);
}
