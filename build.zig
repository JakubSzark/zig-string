const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    _ = b.addModule("string", .{ .root_source_file = b.path("src/root.zig") });

    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/zig-string-tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lldb = b.addSystemCommand(&.{
        "lldb",
        "zig-out/bin/test",
    });

    const run_lib_unit_tests = b.addRunArtifact(main_tests);
    const install_unit_tests = b.addInstallBinFile(main_tests.getEmittedBin(), "test");

    const tests = b.step("test", "Run library tests");
    const lldb_test = b.step("debug", "Run library tests from lldb");
    const install_test = b.step("build_debug", "Install tests to zig-out/bin/");
    tests.dependOn(&run_lib_unit_tests.step);

    install_test.dependOn(&main_tests.step);
    install_test.dependOn(&install_unit_tests.step);

    lldb_test.dependOn(&lldb.step);
    lldb_test.dependOn(&install_unit_tests.step);
}
