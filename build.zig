const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "16bits-audio-mcp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the MCP server");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Test step
    const test_step = b.step("test", "Run unit tests");

    const oscillator_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/audio/oscillator.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(oscillator_tests).step);

    const envelope_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/audio/envelope.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(envelope_tests).step);

    const sequencer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/audio/sequencer.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(sequencer_tests).step);

    const filter_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/audio/filter.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(filter_tests).step);

    const effects_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/audio/effects.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(effects_tests).step);

    const mixer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/audio/mixer.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(mixer_tests).step);

    const wav_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/audio/wav.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(wav_tests).step);

    const fm_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/audio/fm.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(fm_tests).step);
}
