const std = @import("std");
const Build = std.build;

pub fn build(b: *Build) void {
    const ziglangSetMod = b.addModule("ziglangset", .{
        .root_source_file = .{.path = "src/set.zig"},
    });

    _ = ziglangSetMod;
}