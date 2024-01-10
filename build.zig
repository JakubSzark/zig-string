const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{ .name = "zig-string", .root_source_file = .{ .path = "zig-string.zig" }, .target = target, .optimize = optimize });

    b.installArtifact(lib);

    _ = b.addModule("string", .{ .root_source_file = .{ .path = "zig-string.zig" } });

    var main_tests = b.addTest(.{
        .root_source_file = .{ .path = "zig-string-tests.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
