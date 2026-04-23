/// Open Source Initiative OSI - The MIT License (MIT):Licensing
/// The MIT License (MIT)
/// Copyright (c) 2026 Ralph Caraveo (deckarep@gmail.com)
/// Permission is hereby granted, free of charge, to any person obtaining a copy of
/// this software and associated documentation files (the "Software"), to deal in
/// the Software without restriction, including without limitation the rights to
/// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
/// of the Software, and to permit persons to whom the Software is furnished to do
/// so, subject to the following conditions:
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.
///
///
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
