const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard optimize option allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    _ = b.addModule("ziglangSet", .{
        .root_source_file = .{.path = "src/set.zig"},
    });

    const main_tests = b.addTest(.{
        .name = "ziglang-set tests",
        .root_source_file = .{ .path = "src/set.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}