const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("string", .{
        .root_source_file = b.path("zig-string.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_mod = b.addModule("string-tests", .{
        .root_source_file = b.path("zig-string-tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    const main_tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
