/// Open Source Initiative OSI - The MIT License (MIT):Licensing
/// The MIT License (MIT)
/// Copyright (c) 2024 Ralph Caraveo (deckarep@gmail.com)
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

/// comptime selection of the map type for string vs everything else.
fn selectMap(comptime E: type) type {
    comptime {
        if (E == []const u8) {
            return std.StringHashMapUnmanaged(void);
        } else {
            return std.AutoHashMapUnmanaged(E, void);
        }
    }
}

/// HashSetUnmanaged is an implementation of a Set where there is no internal
/// allocator and all allocating methods require a first argument allocator.
/// This is a more compact Set built on top of the the HashMapUnmanaged
/// datastructure.
pub fn HashSetUnmanaged(comptime E: type) type {
    return struct {
        /// The type of the internal hash map
        pub const Map = selectMap(E);

        unmanaged: Map,

        pub const Size = Map.Size;
        /// The iterator type returned by iterator(), key-only for sets
        pub const Iterator = Map.KeyIterator;

        const Self = @This();

        /// Initialzies a Set with the given Allocator
        pub fn init() Self {
            return .{
                .unmanaged = Map{},
            };
        }

        /// Initialzies a Set using a capacity hint, with the given Allocator
        pub fn initCapacity(allocator: Allocator, num: Size) Allocator.Error!Self {
            var self = Self.init();
            try self.unmanaged.ensureTotalCapacity(allocator, num);
            return self;
        }

        /// Destroys the unmanaged Set.
        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.unmanaged.deinit(allocator);
            self.* = undefined;
        }

        pub fn add(self: *Self, allocator: Allocator, element: E) Allocator.Error!bool {
            const prevCount = self.unmanaged.count();
            try self.unmanaged.put(allocator, element, {});
            return prevCount != self.unmanaged.count();
        }

        /// Adds a single element to the set. Asserts that there is enough capacity.
        /// A bool is returned indicating if the element was actually added
        /// if not already known.
        pub fn addAssumeCapacity(self: *Self, element: E) bool {
            const prevCount = self.unmanaged.count();
            self.unmanaged.putAssumeCapacity(element, {});
            return prevCount != self.unmanaged.count();
        }

        /// Appends all elements from the provided set, and may allocate.
        /// append returns an Allocator.Error or Size which represents how
        /// many elements added and not previously in the Set.
        pub fn append(self: *Self, allocator: Allocator, other: Self) Allocator.Error!Size {
            const prevCount = self.unmanaged.count();

            try self.unionUpdate(allocator, other);
            return self.unmanaged.count() - prevCount;
        }

        /// Appends all elements from the provided slice, and may allocate.
        /// appendSlice returns an Allocator.Error or Size which represents how
        /// many elements added and not previously in the slice.
        pub fn appendSlice(self: *Self, allocator: Allocator, elements: []const E) Allocator.Error!Size {
            const prevCount = self.unmanaged.count();
            for (elements) |el| {
                try self.unmanaged.put(allocator, el, {});
            }
            return self.unmanaged.count() - prevCount;
        }

        /// Returns the number of total elements which may be present before
        /// it is no longer guaranteed that no allocations will be performed.
        pub fn capacity(self: *Self) Size {
            // Note: map.capacity() requires mutable access, probably an oversight.
            return self.unmanaged.capacity();
        }

        /// Cardinality effectively returns the size of the set.
        pub fn cardinality(self: Self) Size {
            return self.unmanaged.count();
        }

        /// Invalidates all element pointers.
        pub fn clearAndFree(self: *Self, allocator: Allocator) void {
            self.unmanaged.clearAndFree(allocator);
        }

        /// Invalidates all element pointers.
        pub fn clearRetainingCapacity(self: *Self) void {
            self.unmanaged.clearRetainingCapacity();
        }

        /// Creates a copy of this set, using the same allocator.
        /// clone may return an Allocator.Error or the cloned Set.
        pub fn clone(self: *Self, allocator: Allocator) Allocator.Error!Self {
            // Take a stack copy of self.
            var cloneSelf = self.*;
            // Clone the interal map.
            cloneSelf.unmanaged = try self.unmanaged.clone(allocator);
            return cloneSelf;
        }

        /// Returns true when the provided element exists within the Set otherwise false.
        pub fn contains(self: Self, element: E) bool {
            return self.unmanaged.contains(element);
        }

        /// Returns true when all elements in the other Set are present in this Set
        /// otherwise false.
        pub fn containsAll(self: Self, other: Self) bool {
            var iter = other.iterator();
            while (iter.next()) |el| {
                if (!self.unmanaged.contains(el.*)) {
                    return false;
                }
            }
            return true;
        }

        /// Returns true when all elements in the provided slice are present otherwise false.
        pub fn containsAllSlice(self: Self, elements: []const E) bool {
            for (elements) |el| {
                if (!self.unmanaged.contains(el)) {
                    return false;
                }
            }
            return true;
        }

        /// Returns true when at least one or more elements from the other Set exist within
        /// this Set otherwise false.
        pub fn containsAny(self: Self, other: Self) bool {
            var iter = other.iterator();
            while (iter.next()) |el| {
                if (self.unmanaged.contains(el.*)) {
                    return true;
                }
            }
            return false;
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
        pub fn differenceOf(self: Self, allocator: Allocator, other: Self) Allocator.Error!Self {
            var diffSet = Self.init();

            var iter = self.unmanaged.iterator();
            while (iter.next()) |entry| {
                if (!other.unmanaged.contains(entry.key_ptr.*)) {
                    _ = try diffSet.add(allocator, entry.key_ptr.*);
                }
            }
            return diffSet;
        }

        /// differenceUpdate does an in-place mutation of this set
        /// and other. This set will contain all elements of this set that are not
        /// also elements of other.
        pub fn differenceUpdate(self: *Self, allocator: Allocator, other: Self) Allocator.Error!void {
            // In-place mutation invalidates iterators therefore a temp set is needed.
            // So instead of a temp set, just invoke the regular full function which
            // allocates and returns a set then swap out the map internally.

            // Also, this saves a step of not having to possibly discard many elements
            // from the self set.

            // Just get a new set with the normal method.
            const diffSet = try self.differenceOf(allocator, other);

            // Destroy the internal map.
            self.unmanaged.deinit(allocator);

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
        pub fn ensureTotalCapacity(self: *Self, allocator: Allocator, expected_count: Size) Allocator.Error!void {
            return self.unmanaged.ensureTotalCapacity(allocator, expected_count);
        }

        /// Increases capacity, guaranteeing that insertions up until
        /// `additional_count` **more** items will not cause an allocation, and
        /// therefore cannot fail.
        pub fn ensureUnusedCapacity(self: *Self, allocator: Allocator, additional_count: Size) Allocator.Error!void {
            return self.unmanaged.ensureUnusedCapacity(allocator, additional_count);
        }

        /// eql determines if two sets are equal to each
        /// other. If they have the same cardinality
        /// and contain the same elements, they are
        /// considered equal. The order in which
        /// the elements were added is irrelevant.
        pub fn eql(self: Self, other: Self) bool {
            // First discriminate on cardinalities of both sets.
            if (self.unmanaged.count() != other.unmanaged.count()) {
                return false;
            }

            // Now check for each element one for one and exit early
            // on the first non-match.
            var iter = self.unmanaged.iterator();
            while (iter.next()) |entry| {
                if (!other.unmanaged.contains(entry.key_ptr.*)) {
                    return false;
                }
            }

            return true;
        }

        /// intersectionOf returns a new set containing only the elements
        /// that exist only in both sets.
        ///
        /// Caller owns the newly allocated/returned set.
        pub fn intersectionOf(self: Self, allocator: Allocator, other: Self) Allocator.Error!Self {
            var interSet = Self.init();

            // Optimization: iterate over whichever set is smaller.
            // Matters when disparity in cardinality is large.
            var s = other;
            var o = self;
            if (self.unmanaged.count() < other.unmanaged.count()) {
                s = self;
                o = other;
            }

            var iter = s.unmanaged.iterator();
            while (iter.next()) |entry| {
                if (o.unmanaged.contains(entry.key_ptr.*)) {
                    _ = try interSet.add(allocator, entry.key_ptr.*);
                }
            }

            return interSet;
        }

        /// intersectionUpdate does an in-place intersecting update
        /// to the current set from the other set keeping only
        /// elements found in this Set and the other Set.
        pub fn intersectionUpdate(self: *Self, allocator: Allocator, other: Self) Allocator.Error!void {
            // In-place mutation invalidates iterators therefore a temp set is needed.
            // So instead of a temp set, just invoke the regular full function which
            // allocates and returns a set then swap out the map internally.

            // Also, this saves a step of not having to possibly discard many elements
            // from the self set.

            // Just get a new set with the normal method.
            const interSet = try self.intersectionOf(allocator, other);

            // Destroy the internal map.
            self.unmanaged.deinit(allocator);

            // Swap it out with the new set.
            self.unmanaged = interSet.unmanaged;
        }

        pub fn isEmpty(self: Self) bool {
            return self.unmanaged.count() == 0;
        }

        /// Create an iterator over the elements in the set.
        /// The iterator is invalidated if the set is modified during iteration.
        pub fn iterator(self: Self) Iterator {
            return self.unmanaged.keyIterator();
        }

        /// properSubsetOf determines if every element in this set is in
        /// the other set but the two sets are not equal.
        pub fn properSubsetOf(self: Self, other: Self) bool {
            return self.unmanaged.count() < other.unmanaged.count() and self.subsetOf(other);
        }

        /// properSupersetOf determines if every element in the other set
        /// is in this set but the two sets are not equal.
        pub fn properSupersetOf(self: Self, other: Self) bool {
            return self.unmanaged.count() > other.unmanaged.count() and self.supersetOf(other);
        }

        /// subsetOf determines if every element in this set is in
        /// the other set.
        pub fn subsetOf(self: Self, other: Self) bool {
            // First discriminate on cardinalties of both sets.
            if (self.unmanaged.count() > other.unmanaged.count()) {
                return false;
            }

            // Now check that self set has at least some elements from other.
            var iter = self.unmanaged.iterator();
            while (iter.next()) |entry| {
                if (!other.unmanaged.contains(entry.key_ptr.*)) {
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
            if (self.unmanaged.count() > 0) {
                var iter = self.unmanaged.iterator();
                // NOTE: No in-place mutation as it invalidates live iterators.
                // So a temporary capture is taken.
                var capturedElement: E = undefined;
                while (iter.next()) |entry| {
                    capturedElement = entry.key_ptr.*;
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
        pub fn symmetricDifferenceOf(self: Self, allocator: Allocator, other: Self) Allocator.Error!Self {
            var sdSet = Self.init();

            var iter = self.unmanaged.iterator();
            while (iter.next()) |entry| {
                if (!other.unmanaged.contains(entry.key_ptr.*)) {
                    _ = try sdSet.add(allocator, entry.key_ptr.*);
                }
            }

            iter = other.unmanaged.iterator();
            while (iter.next()) |entry| {
                if (!self.unmanaged.contains(entry.key_ptr.*)) {
                    _ = try sdSet.add(allocator, entry.key_ptr.*);
                }
            }

            return sdSet;
        }

        /// symmetricDifferenceUpdate does an in-place mutation with all elements
        /// which are in either this set or the other set but not in both.
        pub fn symmetricDifferenceUpdate(self: *Self, allocator: Allocator, other: Self) Allocator.Error!void {
            // In-place mutation invalidates iterators therefore a temp set is needed.
            // So instead of a temp set, just invoke the regular full function which
            // allocates and returns a set then swap out the map internally.

            // Also, this saves a step of not having to possibly discard many elements
            // from the self set.

            // Just get a new set with the normal method.
            const sd = try self.symmetricDifferenceOf(allocator, other);

            // Destroy the internal map.
            self.unmanaged.deinit(allocator);

            // Swap it out with the new set.
            self.unmanaged = sd.unmanaged;
        }

        /// union returns a new set with all elements in both sets.
        ///
        /// The caller owns the newly allocated/returned Set.
        pub fn unionOf(self: Self, allocator: Allocator, other: Self) Allocator.Error!Self {
            // Sniff out larger set for capacity hint.
            var n = self.unmanaged.count();
            if (other.unmanaged.count() > n) n = other.unmanaged.count();

            var uSet = try Self.initCapacity(
                allocator,
                @intCast(n),
            );

            var iter = self.unmanaged.iterator();
            while (iter.next()) |entry| {
                _ = try uSet.add(allocator, entry.key_ptr.*);
            }

            iter = other.unmanaged.iterator();
            while (iter.next()) |entry| {
                _ = try uSet.add(allocator, entry.key_ptr.*);
            }

            return uSet;
        }

        /// unionUpdate does an in-place union of the current Set and other Set.
        ///
        /// Allocations may occur.
        pub fn unionUpdate(self: *Self, allocator: Allocator, other: Self) Allocator.Error!void {
            var iter = other.unmanaged.iterator();
            while (iter.next()) |entry| {
                _ = try self.add(allocator, entry.key_ptr.*);
            }
        }
    };
}

const testing = std.testing;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "example usage" {
    // Create a set of u32s called A
    var A = HashSetUnmanaged(u32).init();
    defer A.deinit(testing.allocator);

    // Add some data
    _ = try A.add(testing.allocator, 5);
    _ = try A.add(testing.allocator, 6);
    _ = try A.add(testing.allocator, 7);

    // Add more data; single shot, duplicate data is ignored.
    _ = try A.appendSlice(testing.allocator, &.{ 5, 3, 0, 9 });

    // Create another set called B
    var B = HashSetUnmanaged(u32).init();
    defer B.deinit(testing.allocator);

    // Add data to B
    _ = try B.appendSlice(testing.allocator, &.{ 50, 30, 20 });

    // // Get the union of A | B
    var un = try A.unionOf(testing.allocator, B);
    defer un.deinit(testing.allocator);

    try expectEqual(9, un.cardinality());

    // Grab an iterator and dump the contents.
    var iter = un.iterator();
    while (iter.next()) |el| {
        std.log.debug("element: {d}", .{el.*});
    }
}

test "string usage" {
    var A = HashSetUnmanaged([]const u8).init();
    defer A.deinit(testing.allocator);

    var B = HashSetUnmanaged([]const u8).init();
    defer B.deinit(testing.allocator);

    _ = try A.add(testing.allocator, "Hello");
    _ = try B.add(testing.allocator, "World");

    var C = try A.unionOf(testing.allocator, B);
    defer C.deinit(testing.allocator);
    try expectEqual(2, C.cardinality());
    try expect(C.containsAllSlice(&.{ "Hello", "World" }));
}

test "comprehensive usage" {
    var set = HashSetUnmanaged(u32).init();
    defer set.deinit(testing.allocator);

    try expect(set.isEmpty());

    _ = try set.add(testing.allocator, 8);
    _ = try set.add(testing.allocator, 6);
    _ = try set.add(testing.allocator, 7);
    try expectEqual(set.cardinality(), 3);

    _ = try set.appendSlice(testing.allocator, &.{ 5, 3, 0, 9 });

    // Positive cases.
    try expect(set.contains(8));
    try expect(set.containsAllSlice(&.{ 5, 3, 9 }));
    try expect(set.containsAnySlice(&.{ 5, 55, 12 }));

    // Negative cases.
    try expect(!set.contains(99));
    try expect(!set.containsAllSlice(&.{ 8, 6, 77 }));
    try expect(!set.containsAnySlice(&.{ 99, 55, 44 }));

    try expectEqual(set.cardinality(), 7);

    var other = HashSetUnmanaged(u32).init();
    defer other.deinit(testing.allocator);

    try expect(other.isEmpty());

    _ = try other.add(testing.allocator, 8);
    _ = try other.add(testing.allocator, 6);
    _ = try other.add(testing.allocator, 7);

    _ = try other.appendSlice(testing.allocator, &.{ 5, 3, 0, 9 });

    try expect(set.eql(other));
    try expectEqual(other.cardinality(), 7);

    try expect(other.remove(8));
    try expectEqual(other.cardinality(), 6);
    try expect(!other.remove(55));
    try expect(!set.eql(other));

    other.removeAllSlice(&.{ 6, 7 });
    try expectEqual(other.cardinality(), 4);

    // intersectionOf
    var inter = try set.intersectionOf(testing.allocator, other);
    defer inter.deinit(testing.allocator);
    try expect(!inter.isEmpty());
    try expectEqual(inter.cardinality(), 4);
    try expect(inter.containsAllSlice(&.{ 5, 3, 0, 9 }));

    // Union
    var un = try set.unionOf(testing.allocator, other);
    defer un.deinit(testing.allocator);
    try expect(!un.isEmpty());
    try expectEqual(un.cardinality(), 7);
    try expect(un.containsAllSlice(&.{ 8, 6, 7, 5, 3, 0, 9 }));

    // differenceOf
    var diff = try set.differenceOf(testing.allocator, other);
    defer diff.deinit(testing.allocator);
    try expect(!diff.isEmpty());
    try expectEqual(diff.cardinality(), 3);
    try expect(diff.containsAllSlice(&.{ 8, 7, 6 }));

    // symmetricDifferenceOf
    _ = try set.add(testing.allocator, 11111);
    _ = try set.add(testing.allocator, 9999);
    _ = try other.add(testing.allocator, 7777);
    var symmDiff = try set.symmetricDifferenceOf(testing.allocator, other);
    defer symmDiff.deinit(testing.allocator);
    try expect(!symmDiff.isEmpty());
    try expectEqual(symmDiff.cardinality(), 6);
    try expect(symmDiff.containsAllSlice(&.{ 7777, 11111, 8, 7, 6, 9999 }));

    // subsetOf

    // supersetOf
}

test "clone" {

    // clone
    var a = HashSetUnmanaged(u32).init();
    defer a.deinit(testing.allocator);
    _ = try a.appendSlice(testing.allocator, &.{ 20, 30, 40 });

    var b = try a.clone(testing.allocator);
    defer b.deinit(testing.allocator);

    try expect(a.eql(b));
}

test "clear/capacity" {
    var a = HashSetUnmanaged(u32).init();
    defer a.deinit(testing.allocator);

    try expectEqual(0, a.cardinality());
    try expectEqual(0, a.capacity());

    const cap = 99;
    var b = try HashSetUnmanaged(u32).initCapacity(testing.allocator, cap);
    defer b.deinit(testing.allocator);

    try expectEqual(0, b.cardinality());
    try expect(b.capacity() >= cap);

    for (0..cap) |val| {
        _ = try b.add(testing.allocator, @intCast(val));
    }

    try expectEqual(99, b.cardinality());
    try expect(b.capacity() >= cap);

    b.clearRetainingCapacity();

    try expectEqual(0, b.cardinality());
    try expect(b.capacity() >= cap);

    b.clearAndFree(testing.allocator);

    try expectEqual(0, b.cardinality());
    try expectEqual(b.capacity(), 0);
}

test "iterator" {
    var a = HashSetUnmanaged(u32).init();
    defer a.deinit(testing.allocator);
    _ = try a.appendSlice(testing.allocator, &.{ 20, 30, 40 });

    var sum: u32 = 0;
    var iterCount: usize = 0;
    var iter = a.iterator();
    while (iter.next()) |el| {
        sum += el.*;
        iterCount += 1;
    }

    try expectEqual(90, sum);
    try expectEqual(3, iterCount);
}

test "pop" {
    var a = HashSetUnmanaged(u32).init();
    defer a.deinit(testing.allocator);
    _ = try a.appendSlice(testing.allocator, &.{ 20, 30, 40 });

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

test "in-place methods" {
    // intersectionUpdate
    var a = HashSetUnmanaged(u32).init();
    defer a.deinit(testing.allocator);
    _ = try a.appendSlice(testing.allocator, &.{ 10, 20, 30, 40 });

    var b = HashSetUnmanaged(u32).init();
    defer b.deinit(testing.allocator);
    _ = try b.appendSlice(testing.allocator, &.{ 44, 20, 30, 66 });

    try a.intersectionUpdate(testing.allocator, b);
    try expectEqual(a.cardinality(), 2);
    try expect(a.containsAllSlice(&.{ 20, 30 }));

    // unionUpdate
    var c = HashSetUnmanaged(u32).init();
    defer c.deinit(testing.allocator);
    _ = try c.appendSlice(testing.allocator, &.{ 10, 20, 30, 40 });

    var d = HashSetUnmanaged(u32).init();
    defer d.deinit(testing.allocator);
    _ = try d.appendSlice(testing.allocator, &.{ 44, 20, 30, 66 });

    try c.unionUpdate(testing.allocator, d);
    try expectEqual(c.cardinality(), 6);
    try expect(c.containsAllSlice(&.{ 10, 20, 30, 40, 66 }));

    // differenceUpdate
    var e = HashSetUnmanaged(u32).init();
    defer e.deinit(testing.allocator);
    _ = try e.appendSlice(testing.allocator, &.{ 1, 11, 111, 1111, 11111 });

    var f = HashSetUnmanaged(u32).init();
    defer f.deinit(testing.allocator);
    _ = try f.appendSlice(testing.allocator, &.{ 1, 11, 111, 222, 2222, 1111 });

    try e.differenceUpdate(testing.allocator, f);

    try expectEqual(1, e.cardinality());
    try expect(e.contains(11111));

    // symmetricDifferenceUpdate
    var g = HashSetUnmanaged(u32).init();
    defer g.deinit(testing.allocator);
    _ = try g.appendSlice(testing.allocator, &.{ 2, 22, 222, 2222, 22222 });

    var h = HashSetUnmanaged(u32).init();
    defer h.deinit(testing.allocator);
    _ = try h.appendSlice(testing.allocator, &.{ 1, 11, 111, 333, 3333, 2222, 1111 });

    try g.symmetricDifferenceUpdate(testing.allocator, h);

    try expectEqual(10, g.cardinality());
    try expect(g.containsAllSlice(&.{ 1, 2, 11, 111, 22, 222, 1111, 333, 3333, 22222 }));
}

test "sizeOf matches" {
    // No bloat guarantee, after all we're just building on top of what's good.
    // "What's good Miley!?!?""
    const expectedByteSize = 24;
    try expectEqual(expectedByteSize, @sizeOf(std.hash_map.AutoHashMapUnmanaged(u32, void)));
    try expectEqual(expectedByteSize, @sizeOf(HashSetUnmanaged(u32)));
}
