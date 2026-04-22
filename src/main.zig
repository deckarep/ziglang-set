const std = @import("std");
const set = @import("root.zig");

const HashSet = set.HashSet;
const ArraySet = set.ArraySet;

const SimpleHasher = struct {
    const Self = @This();
    pub fn hash(_: Self, key: u32) u64 {
        return @as(u64, key) *% 0x517cc1b727220a95;
    }
    pub fn eql(_: Self, a: u32, b: u32) bool {
        return a == b;
    }
};

pub fn main(init: std.process.Init) void {
    const gpa = init.gpa;

    // now we can initialize a HashSet with empty if no context is provided
    var A: HashSet(u32) = .empty;
    defer A.deinit(gpa);
    
    var B: ArraySet(u32) = .empty;
    defer B.deinit(gpa);

    const ctx = SimpleHasher{};
    var C: set.HashSetContext(u32, SimpleHasher, 75) = .initContext(ctx);
    defer C.deinit(gpa);
    
}
