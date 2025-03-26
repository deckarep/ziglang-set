/// Open Source Initiative OSI - The MIT License (MIT):Licensing
/// The MIT License (MIT)
/// Copyright (c) 2025 Ralph Caraveo (deckarep@gmail.com)
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
const mem = std.mem;
const Allocator = mem.Allocator;
const ArraySetUnmanaged = @import("unmanaged.zig").ArraySetUnmanaged;

pub fn ArraySetManaged(comptime E: type) type {
    return struct {
        allocator: Allocator,

        unmanaged: Set,

        /// The type of the internal array hash map
        pub const Set = ArraySetUnmanaged(E);

        /// The integer type used to store the size of the map, borrowed from map
        pub const Size = Set.Size;
        /// The iterator type returned by iterator(), key-only for sets
        pub const Iterator = Set.Iterator;

        const Self = @This();

        /// Initialzies a Set with the given Allocator
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .unmanaged = Set.init(),
            };
        }

        /// Initialzies a Set using a capacity hint, with the given Allocator
        pub fn initCapacity(allocator: Allocator, num: Size) Allocator.Error!Self {
            var self = Self.init(allocator);
            self.allocator = allocator;
            try self.unmanaged.ensureTotalCapacity(allocator, num);
            return self;
        }

        /// Destory the Set
        pub fn deinit(self: *Self) void {
            self.unmanaged.deinit(self.allocator);
            self.* = undefined;
        }

        /// Adds a single element to the set and an allocation may occur.
        /// add may return an Allocator.Error or bool indicating if the element
        /// was actually added if not already known.
        pub fn add(self: *Self, element: E) Allocator.Error!bool {
            return self.unmanaged.add(self.allocator, element);
        }

        /// Adds a single element to the set. Asserts that there is enough capacity.
        /// A bool is returned indicating if the element was actually added
        /// if not already known.
        pub fn addAssumeCapacity(self: *Self, element: E) bool {
            return self.unmanaged.add(self.allocator, element) catch unreachable;
        }

        /// Appends all elements from the provided set, and may allocate.
        /// append returns an Allocator.Error or Size which represents how
        /// many elements added and not previously in the Set.
        pub fn append(self: *Self, other: Self) Allocator.Error!Size {
            const prevCount = self.unmanaged.cardinality();
            // Directly access the underlying map instead of using unionUpdate
            // We avoid double existence/capacity checks by accessing map directly
            var iter = other.unmanaged.iterator();
            while (iter.next()) |entry| {
                _ = try self.unmanaged.put(self.allocator, entry.key_ptr.*, {});
            }
            return self.unmanaged.cardinality() - prevCount;
        }

        /// Appends all elements from the provided slice, and may allocate.
        /// appendSlice returns an Allocator.Error or Size which represents how
        /// many elements added and not previously in the slice.
        pub fn appendSlice(self: *Self, elements: []const E) Allocator.Error!Size {
            const prevCount = self.unmanaged.cardinality();
            for (elements) |el| {
                _ = try self.unmanaged.add(self.allocator, el);
            }
            return self.unmanaged.cardinality() - prevCount;
        }

        /// Returns the number of total elements which may be present before
        /// it is no longer guaranteed that no allocations will be performed.
        pub fn capacity(self: *Self) Size {
            // Note: map.capacity() requires mutable access, probably an oversight.
            return self.unmanaged.capacity();
        }

        /// Cardinality effectively returns the size of the set
        pub fn cardinality(self: Self) Size {
            return self.unmanaged.cardinality();
        }

        /// Invalidates all element pointers.
        pub fn clearAndFree(self: *Self) void {
            self.unmanaged.clearAndFree(self.allocator);
        }

        /// Invalidates all element pointers.
        pub fn clearRetainingCapacity(self: *Self) void {
            self.unmanaged.clearRetainingCapacity();
        }

        /// Creates a copy of this set, using the same allocator.
        /// clone may return an Allocator.Error or the cloned Set.
        pub fn clone(self: *Self) Allocator.Error!Self {
            // Take a stack copy of self.
            var cloneSelf = self.*;
            // Clone the interal map.
            cloneSelf.unmanaged = try self.unmanaged.clone(self.allocator);
            return cloneSelf;
        }

        /// Creates a copy of this set, using a specified allocator.
        /// cloneWithAllocator may be return an Allocator.Error or the cloned Set.
        pub fn cloneWithAllocator(self: *Self, allocator: Allocator) Allocator.Error!Self {
            // Directly clone the unmanaged structure with the new allocator
            const clonedUnmanaged = try self.unmanaged.cloneWithAllocator(allocator);
            return Self{
                .allocator = allocator,
                .unmanaged = clonedUnmanaged,
            };
        }

        /// Returns true when the provided element exists within the Set otherwise false.
        pub fn contains(self: Self, element: E) bool {
            return self.unmanaged.contains(element);
        }

        /// Returns true when all elements in the other Set are present in this Set
        /// otherwise false.
        pub fn containsAll(self: Self, other: Self) bool {
            return self.unmanaged.containsAll(other.unmanaged);
        }

        /// Returns true when all elements in the provided slice are present otherwise false.
        pub fn containsAllSlice(self: Self, elements: []const E) bool {
            return self.unmanaged.containsAllSlice(elements);
        }

        /// Returns true when at least one or more elements from the other Set exist within
        /// this Set otherwise false.
        pub fn containsAny(self: Self, other: Self) bool {
            // Delegate to the unmanaged implementation which might have optimizations
            return self.unmanaged.containsAny(other.unmanaged);
        }

        /// Returns true when at least one or more elements from the slice exist within
        /// this Set otherwise false.
        pub fn containsAnySlice(self: Self, elements: []const E) bool {
            for (elements) |el| {
                if (self.unmanaged.contains(el)) {
                    return true;
                }
            }
            return false;
        }

        /// differenceOf returns the difference between this set
        /// and other. The returned set will contain
        /// all elements of this set that are not also
        /// elements of the other.
        ///
        /// Caller owns the newly allocated/returned set.
        pub fn differenceOf(self: Self, other: Self) Allocator.Error!Self {
            // Delegate to unmanaged implementation to avoid double iteration
            const diffUnmanaged = try self.unmanaged.differenceOf(self.allocator, other.unmanaged);
            return Self{
                .allocator = self.allocator,
                .unmanaged = diffUnmanaged,
            };
        }

        /// differenceUpdate does an in-place mutation of this set
        /// and other. This set will contain all elements of this set that are not
        /// also elements of other.
        pub fn differenceUpdate(self: *Self, other: Self) Allocator.Error!void {
            // In-place mutation invalidates iterators therefore a temp set is needed.
            // So instead of a temp set, just invoke the regular full function which
            // allocates and returns a set then swap out the map internally.

            // Also, this saves a step of not having to possibly discard many elements
            // from the self set.

            // Just get a new set with the normal method.
            const diffSet = try self.differenceOf(other);

            // Destroy the internal map.
            self.unmanaged.deinit(self.allocator);

            // Swap it out with the new set.
            self.unmanaged = diffSet.unmanaged;
        }

        fn dump(self: Self) void {
            std.log.err("\ncardinality: {d}\n", .{self.cardinality()});
            var iter = self.iterator();
            while (iter.next()) |el| {
                std.log.err("  element: {d}\n", .{el.*});
            }
        }

        /// Increases capacity, guaranteeing that insertions up until the
        /// `expected_count` will not cause an allocation, and therefore cannot fail.
        pub fn ensureTotalCapacity(self: *Self, expected_count: Size) Allocator.Error!void {
            return self.unmanaged.ensureTotalCapacity(expected_count);
        }

        /// Increases capacity, guaranteeing that insertions up until
        /// `additional_count` **more** items will not cause an allocation, and
        /// therefore cannot fail.
        pub fn ensureUnusedCapacity(self: *Self, additional_count: Size) Allocator.Error!void {
            return self.unmanaged.ensureUnusedCapacity(additional_count);
        }

        /// eql determines if two sets are equal to each
        /// other. If they have the same cardinality
        /// and contain the same elements, they are
        /// considered equal. The order in which
        /// the elements were added is irrelevant.
        pub fn eql(self: Self, other: Self) bool {
            // First discriminate on cardinalities of both sets.
            if (self.unmanaged.cardinality() != other.unmanaged.cardinality()) {
                return false;
            }

            // Now check for each element one for one and exit early
            // on the first non-match.
            var iter = self.unmanaged.iterator();
            while (iter.next()) |pVal| {
                if (!other.unmanaged.contains(pVal.key_ptr.*)) {
                    return false;
                }
            }

            return true;
        }

        /// intersectionOf returns a new set containing only the elements
        /// that exist only in both sets.
        ///
        /// Caller owns the newly allocated/returned set.
        pub fn intersectionOf(self: Self, other: Self) Allocator.Error!Self {
            const interUnmanaged = try self.unmanaged.intersectionOf(self.allocator, other.unmanaged);
            return Self{
                .allocator = self.allocator,
                .unmanaged = interUnmanaged,
            };
        }

        /// intersectionUpdate does an in-place intersecting update
        /// to the current set from the other set keeping only
        /// elements found in this Set and the other Set.
        pub fn intersectionUpdate(self: *Self, other: Self) Allocator.Error!void {
            // In-place mutation invalidates iterators therefore a temp set is needed.
            // So instead of a temp set, just invoke the regular full function which
            // allocates and returns a set then swap out the map internally.

            // Also, this saves a step of not having to possibly discard many elements
            // from the self set.

            // Just get a new set with the normal method.
            const interSet = try self.intersectionOf(other);

            // Destroy the internal map.
            self.unmanaged.deinit(self.allocator);

            // Swap it out with the new set.
            self.unmanaged = interSet.unmanaged;
        }

        /// In place style:
        /// differenceOfUpdate
        /// symmetric_differenceOf_update
        /// Returns true if the set is empty otherwise false
        pub fn isEmpty(self: Self) bool {
            return self.unmanaged.cardinality() == 0;
        }

        /// Create an iterator over the elements in the set.
        /// The iterator is invalidated if the set is modified during iteration.
        pub fn iterator(self: Self) Iterator {
            return self.unmanaged.iterator();
        }

        /// properSubsetOf determines if every element in this set is in
        /// the other set but the two sets are not equal.
        pub fn properSubsetOf(self: Self, other: Self) bool {
            return self.unmanaged.cardinality() < other.unmanaged.cardinality() and self.subsetOf(other);
        }

        /// properSupersetOf determines if every element in the other set
        /// is in this set but the two sets are not equal.
        pub fn properSupersetOf(self: Self, other: Self) bool {
            return self.unmanaged.cardinality() > other.unmanaged.cardinality() and self.supersetOf(other);
        }

        /// subsetOf determines if every element in this set is in
        /// the other set.
        pub fn subsetOf(self: Self, other: Self) bool {
            // First discriminate on cardinalties of both sets.
            if (self.unmanaged.cardinality() > other.unmanaged.cardinality()) {
                return false;
            }

            // Now check that self set has at least some elements from other.
            var iter = self.unmanaged.iterator();
            while (iter.next()) |pVal| {
                if (!other.unmanaged.contains(pVal.key_ptr.*)) {
                    return false;
                }
            }

            return true;
        }

        /// subsetOf determines if every element in the other Set is in
        /// the this Set.
        pub fn supersetOf(self: Self, other: Self) bool {
            // This is just the converse of subsetOf.
            return other.subsetOf(self);
        }

        /// pop removes and returns an arbitrary ?E from the set.
        /// Order is not guaranteed.
        /// This safely returns null if the Set is empty.
        pub fn pop(self: *Self) ?E {
            if (self.unmanaged.cardinality() > 0) {
                var iter = self.unmanaged.iterator();
                // NOTE: No in-place mutation as it invalidates live iterators.
                // So a temporary capture is taken.
                var capturedElement: E = undefined;
                while (iter.next()) |pVal| {
                    capturedElement = pVal.key_ptr.*;
                    break;
                }
                _ = self.unmanaged.remove(capturedElement);
                return capturedElement;
            } else {
                return null;
            }
        }

        /// remove discards a single element from the Set
        pub fn remove(self: *Self, element: E) bool {
            return self.unmanaged.remove(element);
        }

        /// removesAll discards all elements passed from the other Set from
        /// this Set
        pub fn removeAll(self: *Self, other: Self) void {
            var iter = other.iterator();
            while (iter.next()) |el| {
                _ = self.unmanaged.remove(el);
            }
        }

        /// removesAllSlice discards all elements passed as a slice from the Set
        pub fn removeAllSlice(self: *Self, elements: []const E) void {
            for (elements) |el| {
                _ = self.unmanaged.remove(el);
            }
        }

        /// symmetricDifferenceOf returns a new set with all elements which are
        /// in either this set or the other set but not in both.
        ///
        /// The caller owns the newly allocated/returned Set.
        pub fn symmetricDifferenceOf(self: Self, other: Self) Allocator.Error!Self {
            // Use optimized unmanaged implementation
            const sdUnmanaged = try self.unmanaged.symmetricDifferenceOf(self.allocator, other.unmanaged);
            return Self{
                .allocator = self.allocator,
                .unmanaged = sdUnmanaged,
            };
        }

        /// symmetricDifferenceUpdate does an in-place mutation with all elements
        /// which are in either this set or the other set but not in both.
        pub fn symmetricDifferenceUpdate(self: *Self, other: Self) Allocator.Error!void {
            // In-place mutation invalidates iterators therefore a temp set is needed.
            // So instead of a temp set, just invoke the regular full function which
            // allocates and returns a set then swap out the map internally.

            // Also, this saves a step of not having to possibly discard many elements
            // from the self set.

            // Just get a new set with the normal method.
            const sd = try self.symmetricDifferenceOf(other);

            // Destroy the internal map.
            self.unmanaged.deinit(self.allocator);

            // Swap it out with the new set.
            self.unmanaged = sd.unmanaged;
        }

        /// union returns a new set with all elements in both sets.
        ///
        /// The caller owns the newly allocated/returned Set.
        pub fn unionOf(self: Self, other: Self) Allocator.Error!Self {
            const unionUnmanaged = try self.unmanaged.unionOf(self.allocator, other.unmanaged);
            return Self{
                .allocator = self.allocator,
                .unmanaged = unionUnmanaged,
            };
        }

        /// unionUpdate does an in-place union of the current Set and other Set.
        ///
        /// Allocations may occur.
        pub fn unionUpdate(self: *Self, other: Self) Allocator.Error!void {
            var iter = other.unmanaged.iterator();
            while (iter.next()) |pVal| {
                _ = try self.add(pVal.key_ptr.*);
            }
        }
    };
}

const testing = std.testing;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "example usage" {
    // import the namespace.
    // const set = @import("set.zig");

    // Create a set of u32s called A
    var A = ArraySetManaged(u32).init(std.testing.allocator);
    defer A.deinit();

    // Add some data
    _ = try A.add(5);
    _ = try A.add(6);
    _ = try A.add(7);

    // Add more data; single shot, duplicate data is ignored.
    _ = try A.appendSlice(&.{ 5, 3, 0, 9 });

    // Create another set called B
    var B = ArraySetManaged(u32).init(std.testing.allocator);
    defer B.deinit();

    // Add data to B
    _ = try B.appendSlice(&.{ 50, 30, 20 });

    // Get the union of A | B
    var un = try A.unionOf(B);
    defer un.deinit();

    // Grab an iterator and dump the contents.
    var iter = un.iterator();
    while (iter.next()) |el| {
        std.log.debug("element: {d}", .{el.key_ptr.*});
    }
}

test "string usage" {
    var A = ArraySetManaged([]const u8).init(std.testing.allocator);
    defer A.deinit();

    var B = ArraySetManaged([]const u8).init(std.testing.allocator);
    defer B.deinit();

    _ = try A.add("Hello");
    _ = try B.add("World");

    var C = try A.unionOf(B);
    defer C.deinit();
    try expectEqual(2, C.cardinality());
    try expect(C.containsAllSlice(&.{ "Hello", "World" }));
}

test "comprehensive usage" {
    var set = ArraySetManaged(u32).init(std.testing.allocator);
    defer set.deinit();

    try expect(set.isEmpty());

    _ = try set.add(8);
    _ = try set.add(6);
    _ = try set.add(7);
    try expectEqual(set.cardinality(), 3);

    _ = try set.appendSlice(&.{ 5, 3, 0, 9 });

    // Positive cases.
    try expect(set.contains(8));
    try expect(set.containsAllSlice(&.{ 5, 3, 9 }));
    try expect(set.containsAnySlice(&.{ 5, 55, 12 }));

    // Negative cases.
    try expect(!set.contains(99));
    try expect(!set.containsAllSlice(&.{ 8, 6, 77 }));
    try expect(!set.containsAnySlice(&.{ 99, 55, 44 }));

    try expectEqual(set.cardinality(), 7);

    var other = ArraySetManaged(u32).init(std.testing.allocator);
    defer other.deinit();

    try expect(other.isEmpty());

    _ = try other.add(8);
    _ = try other.add(6);
    _ = try other.add(7);

    _ = try other.appendSlice(&.{ 5, 3, 0, 9 });

    try expect(set.eql(other));
    try expectEqual(other.cardinality(), 7);

    try expect(other.remove(8));
    try expectEqual(other.cardinality(), 6);
    try expect(!other.remove(55));
    try expect(!set.eql(other));

    other.removeAllSlice(&.{ 6, 7 });
    try expectEqual(other.cardinality(), 4);

    // intersectionOf
    var inter = try set.intersectionOf(other);
    defer inter.deinit();
    try expect(!inter.isEmpty());
    try expectEqual(inter.cardinality(), 4);
    try expect(inter.containsAllSlice(&.{ 5, 3, 0, 9 }));

    // Union
    var un = try set.unionOf(other);
    defer un.deinit();
    try expect(!un.isEmpty());
    try expectEqual(un.cardinality(), 7);
    try expect(un.containsAllSlice(&.{ 8, 6, 7, 5, 3, 0, 9 }));

    // differenceOf
    var diff = try set.differenceOf(other);
    defer diff.deinit();
    try expect(!diff.isEmpty());
    try expectEqual(diff.cardinality(), 3);
    try expect(diff.containsAllSlice(&.{ 8, 7, 6 }));

    // symmetricDifferenceOf
    _ = try set.add(11111);
    _ = try set.add(9999);
    _ = try other.add(7777);
    var symmDiff = try set.symmetricDifferenceOf(other);
    defer symmDiff.deinit();
    try expect(!symmDiff.isEmpty());
    try expectEqual(symmDiff.cardinality(), 6);
    try expect(symmDiff.containsAllSlice(&.{ 7777, 11111, 8, 7, 6, 9999 }));

    // subsetOf

    // supersetOf
}

test "clear/capacity" {
    var a = ArraySetManaged(u32).init(std.testing.allocator);
    defer a.deinit();

    try expectEqual(0, a.cardinality());
    try expectEqual(0, a.capacity());

    const cap = 99;
    var b = try ArraySetManaged(u32).initCapacity(std.testing.allocator, cap);
    defer b.deinit();

    try expectEqual(0, b.cardinality());
    try expect(b.capacity() >= cap);

    for (0..cap) |val| {
        _ = try b.add(@intCast(val));
    }

    try expectEqual(99, b.cardinality());
    try expect(b.capacity() >= cap);

    b.clearRetainingCapacity();

    try expectEqual(0, b.cardinality());
    try expect(b.capacity() >= cap);

    b.clearAndFree();

    try expectEqual(0, b.cardinality());
    try expectEqual(b.capacity(), 0);
}

test "clone" {
    {
        // clone
        var a = ArraySetManaged(u32).init(std.testing.allocator);
        defer a.deinit();
        _ = try a.appendSlice(&.{ 20, 30, 40 });

        var b = try a.clone();
        defer b.deinit();

        try expect(a.eql(b));
    }

    {
        // cloneWithAllocator
        var a = ArraySetManaged(u32).init(std.testing.allocator);
        defer a.deinit();
        _ = try a.appendSlice(&.{ 20, 30, 40 });

        // Use a different allocator than the test one.
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const tmpAlloc = gpa.allocator();
        defer {
            const deinit_status = gpa.deinit();
            // Fail test; can't try in defer as defer is executed after we return
            if (deinit_status == .leak) expect(false) catch @panic("TEST FAIL");
        }

        var b = try a.cloneWithAllocator(tmpAlloc);
        defer b.deinit();

        try expect(a.allocator.ptr != b.allocator.ptr);
        try expect(a.eql(b));
    }
}

test "pop" {
    var a = ArraySetManaged(u32).init(std.testing.allocator);
    defer a.deinit();
    _ = try a.appendSlice(&.{ 20, 30, 40 });

    // No assumptions can be made about pop order.
    while (a.pop()) |result| {
        try expect(result == 20 or result == 30 or result == 40);
    }

    // At this point, set must be empty.
    try expectEqual(a.cardinality(), 0);
    try expect(a.isEmpty());

    // Lastly, pop should safely return null.
    try expect(a.pop() == null);
}

test "subset/superset" {
    {
        // subsetOf
        var a = ArraySetManaged(u32).init(std.testing.allocator);
        defer a.deinit();
        _ = try a.appendSlice(&.{ 1, 2, 3, 5, 7 });

        var b = ArraySetManaged(u32).init(std.testing.allocator);
        defer b.deinit();

        // b should be a subset of a.
        try expect(b.subsetOf(a));

        _ = try b.add(72);

        // b should not be a subset of a, because 72 is not in a.
        try expect(!b.subsetOf(a));
    }

    {
        // supersetOf
        var a = ArraySetManaged(u32).init(std.testing.allocator);
        defer a.deinit();
        _ = try a.appendSlice(&.{ 9, 5, 2, 1, 11 });

        var b = ArraySetManaged(u32).init(std.testing.allocator);
        defer b.deinit();
        _ = try b.appendSlice(&.{ 5, 2, 11 });

        // set a should be a superset of set b
        try expect(!b.supersetOf(a));

        _ = try b.add(42);

        // TODO: figure out why this fails.
        //set a should not be a superset of set b because b has 42
        // try expect(a.supersetOf(&b));
    }
}

test "iterator" {
    var a = ArraySetManaged(u32).init(std.testing.allocator);
    defer a.deinit();
    _ = try a.appendSlice(&.{ 20, 30, 40 });

    var sum: u32 = 0;
    var iterCount: usize = 0;
    var iter = a.iterator();
    while (iter.next()) |el| {
        sum += el.key_ptr.*;
        iterCount += 1;
    }

    try expectEqual(90, sum);
    try expectEqual(3, iterCount);
}

test "in-place methods" {
    // intersectionUpdate
    var a = ArraySetManaged(u32).init(std.testing.allocator);
    defer a.deinit();
    _ = try a.appendSlice(&.{ 10, 20, 30, 40 });

    var b = ArraySetManaged(u32).init(std.testing.allocator);
    defer b.deinit();
    _ = try b.appendSlice(&.{ 44, 20, 30, 66 });

    try a.intersectionUpdate(b);
    try expectEqual(a.cardinality(), 2);
    try expect(a.containsAllSlice(&.{ 20, 30 }));

    // unionUpdate
    var c = ArraySetManaged(u32).init(std.testing.allocator);
    defer c.deinit();
    _ = try c.appendSlice(&.{ 10, 20, 30, 40 });

    var d = ArraySetManaged(u32).init(std.testing.allocator);
    defer d.deinit();
    _ = try d.appendSlice(&.{ 44, 20, 30, 66 });

    try c.unionUpdate(d);
    try expectEqual(c.cardinality(), 6);
    try expect(c.containsAllSlice(&.{ 10, 20, 30, 40, 66 }));

    // differenceUpdate
    var e = ArraySetManaged(u32).init(std.testing.allocator);
    defer e.deinit();
    _ = try e.appendSlice(&.{ 1, 11, 111, 1111, 11111 });

    var f = ArraySetManaged(u32).init(std.testing.allocator);
    defer f.deinit();
    _ = try f.appendSlice(&.{ 1, 11, 111, 222, 2222, 1111 });

    try e.differenceUpdate(f);

    try expectEqual(1, e.cardinality());
    try expect(e.contains(11111));

    // symmetricDifferenceUpdate
    var g = ArraySetManaged(u32).init(std.testing.allocator);
    defer g.deinit();
    _ = try g.appendSlice(&.{ 2, 22, 222, 2222, 22222 });

    var h = ArraySetManaged(u32).init(std.testing.allocator);
    defer h.deinit();
    _ = try h.appendSlice(&.{ 1, 11, 111, 333, 3333, 2222, 1111 });

    try g.symmetricDifferenceUpdate(h);

    try expectEqual(10, g.cardinality());
    try expect(g.containsAllSlice(&.{ 1, 2, 11, 111, 22, 222, 1111, 333, 3333, 22222 }));
}

test "sizeOf" {
    const unmanagedSize = @sizeOf(ArraySetUnmanaged(u32));
    const managedSize = @sizeOf(ArraySetManaged(u32));

    // The managed must be only 16 bytes larger, the cost of the internal allocator
    // otherwise we've added some CRAP!
    const expectedDiff = 16;
    try expectEqual(expectedDiff, managedSize - unmanagedSize);
}

test "benchmark" {
    const allocator = std.testing.allocator;
    const Iterations = 10_000;
    const SetSize = 1000;

    // Setup
    var base = try ArraySetManaged(u32).initCapacity(allocator, SetSize);
    defer base.deinit();
    for (0..SetSize) |i| _ = base.addAssumeCapacity(@intCast(i));

    var other = try ArraySetManaged(u32).initCapacity(allocator, SetSize);
    defer other.deinit();
    for (0..SetSize) |i| _ = other.addAssumeCapacity(@intCast(i + SetSize / 2));

    // Benchmark unionOf
    var union_timer = try std.time.Timer.start();
    for (0..Iterations) |_| {
        var result = try base.unionOf(other);
        defer result.deinit();
    }
    const union_elapsed = union_timer.read();
    std.debug.print("\nunionOf: {d} ops/sec ({d:.2} ns/op)\n", .{
        Iterations * std.time.ns_per_s / union_elapsed,
        @as(f64, @floatFromInt(union_elapsed)) / @as(f64, @floatFromInt(Iterations)),
    });

    // Benchmark intersectionOf
    var inter_timer = try std.time.Timer.start();
    for (0..Iterations) |_| {
        var result = try base.intersectionOf(other);
        defer result.deinit();
    }
    const inter_elapsed = inter_timer.read();
    std.debug.print("intersectionOf: {d} ops/sec ({d:.2} ns/op)\n", .{
        Iterations * std.time.ns_per_s / inter_elapsed,
        @as(f64, @floatFromInt(inter_elapsed)) / @as(f64, @floatFromInt(Iterations)),
    });

    // Benchmark containsAll
    var contains_timer = try std.time.Timer.start();
    for (0..Iterations) |_| {
        _ = base.containsAll(other);
    }
    const contains_elapsed = contains_timer.read();
    std.debug.print("containsAll: {d} ops/sec ({d:.2} ns/op)\n", .{
        Iterations * std.time.ns_per_s / contains_elapsed,
        @as(f64, @floatFromInt(contains_elapsed)) / @as(f64, @floatFromInt(Iterations)),
    });
}
