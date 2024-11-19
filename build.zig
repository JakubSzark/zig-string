const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("string", .{ .root_source_file = b.path("zig-string.zig") });

    const main_tests = b.addTest(.{
        .root_source_file = b.path("zig-string-tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(main_tests);

    const run_arti = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_arti.step);
}
