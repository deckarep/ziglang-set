const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard optimize option allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    _ = b.addModule("ziglangSet", .{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    const main_tests = b.addTest(.{
        .name = "ziglang-set tests",
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // Below is for docs generation.
    const lib = b.addObject(.{
        .name = "ziglang-set",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const my_docs = lib;
    const build_docs = b.addInstallDirectory(.{
        .source_dir = my_docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const build_docs_step = b.step("docs", "Build the library docs");
    build_docs_step.dependOn(&build_docs.step);
}
