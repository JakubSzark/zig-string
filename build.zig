const Builder = @import("std").build.Builder;
const FileSource = @import("std").build.FileSource;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("string", .{ .source_file = FileSource.relative("zig-string.zig") });

    var main_tests = b.addTest(.{
        .root_source_file = FileSource.relative("zig-string-tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
