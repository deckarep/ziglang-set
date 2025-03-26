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
const math = std.math;
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

/// Select a context-aware hash map type
fn selectMapWithContext(comptime E: type, comptime Context: type, comptime max_load_percentage: u8) type {
    return std.HashMapUnmanaged(E, void, Context, max_load_percentage);
}

/// HashSetUnmanaged is an implementation of a Set where there is no internal
/// allocator and all allocating methods require a first argument allocator.
/// This is a more compact Set built on top of the the HashMapUnmanaged
/// datastructure.
/// Note that max_load_percentage defaults to undefined, because the underlying
/// std.AutoHashMap/std.StringHashMap defaults are used.
pub fn HashSetUnmanaged(comptime E: type) type {
    return HashSetUnmanagedWithContext(E, void, undefined);
}

/// HashSetUnmanagedWithContext creates a set based on element type E with custom hashing behavior.
/// This variant allows specifying:
/// - A Context type that implements hash() and eql() functions for custom element hashing
/// - A max_load_percentage (1-100) that controls hash table resizing
/// If Context is undefined, then max_load_percentage is ignored.
///
/// The Context type must provide:
///   fn hash(self: Context, key: K) u64
///   fn eql(self: Context, a: K, b: K) bool
pub fn HashSetUnmanagedWithContext(comptime E: type, comptime Context: type, comptime max_load_percentage: u8) type {
    return struct {
        /// The type of the internal hash map
        pub const Map = if (Context == void) selectMap(E) else selectMapWithContext(E, Context, max_load_percentage);

        unmanaged: Map,
        context: if (Context == void) void else Context = if (Context == void) {} else undefined,
        max_load_percentage: if (Context == void) void else u8 = if (Context == void) {} else max_load_percentage,

        pub const Size = Map.Size;
        /// The iterator type returned by iterator(), key-only for sets
        pub const Iterator = Map.KeyIterator;

        const Self = @This();

        /// Initialize a default set without context
        pub fn init() Self {
            return .{
                .unmanaged = Map{},
                .context = if (Context == void) {} else undefined,
                .max_load_percentage = if (Context == void) {} else max_load_percentage,
            };
        }

        /// Initialize with a custom context
        pub fn initContext(context: Context) Self {
            return .{
                .unmanaged = Map{},
                .context = context,
                .max_load_percentage = max_load_percentage,
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
        pub fn capacity(self: Self) Size {
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
    const autoHashMapSize = @sizeOf(std.hash_map.AutoHashMapUnmanaged(u32, void));
    const hashSetSize = @sizeOf(HashSetUnmanaged(u32));
    try expectEqual(expectedByteSize, autoHashMapSize);
    try expectEqual(expectedByteSize, hashSetSize);

    // The unmanaged with void context must be the same size as the unmanaged.
    // The unmanaged with context must be larger by the size of the empty Context struct,
    // due to the added Context and alignment padding.
    const expectedContextDiff = 8;
    const hashSetWithVoidContextSize = @sizeOf(HashSetUnmanagedWithContext(u32, void, undefined));
    const hashSetWithContextSize = @sizeOf(HashSetUnmanagedWithContext(u32, TestContext, 75));
    try expectEqual(0, hashSetWithVoidContextSize - hashSetSize);
    try expectEqual(expectedContextDiff, hashSetWithContextSize - hashSetSize);
}

const TestContext = struct {
    const Self = @This();
    pub fn hash(_: Self, key: u32) u64 {
        return @as(u64, key) *% 0x517cc1b727220a95;
    }
    pub fn eql(_: Self, a: u32, b: u32) bool {
        return a == b;
    }
};

test "custom hash function comprehensive" {
    const context = TestContext{};
    var set = HashSetUnmanagedWithContext(u32, TestContext, 75).initContext(context);
    defer set.deinit(testing.allocator);

    // Test basic operations
    _ = try set.add(testing.allocator, 123);
    _ = try set.add(testing.allocator, 456);
    try expect(set.contains(123));
    try expect(set.contains(456));
    try expect(!set.contains(789));
    try expectEqual(set.cardinality(), 2);

    // Test clone with custom context
    var cloned = try set.clone(testing.allocator);
    defer cloned.deinit(testing.allocator);
    try expect(cloned.contains(123));
    try expect(set.eql(cloned));

    // Test set operations with custom context
    var other = HashSetUnmanagedWithContext(u32, TestContext, 75).initContext(context);
    defer other.deinit(testing.allocator);
    _ = try other.add(testing.allocator, 456);
    _ = try other.add(testing.allocator, 789);

    // Test union
    var union_set = try set.unionOf(testing.allocator, other);
    defer union_set.deinit(testing.allocator);
    try expectEqual(union_set.cardinality(), 3);
    try expect(union_set.containsAllSlice(&.{ 123, 456, 789 }));

    // Test intersection
    var intersection = try set.intersectionOf(testing.allocator, other);
    defer intersection.deinit(testing.allocator);
    try expectEqual(intersection.cardinality(), 1);
    try expect(intersection.contains(456));

    // Test difference
    var difference = try set.differenceOf(testing.allocator, other);
    defer difference.deinit(testing.allocator);
    try expectEqual(difference.cardinality(), 1);
    try expect(difference.contains(123));

    // Test symmetric difference
    var sym_diff = try set.symmetricDifferenceOf(testing.allocator, other);
    defer sym_diff.deinit(testing.allocator);
    try expectEqual(sym_diff.cardinality(), 2);
    try expect(sym_diff.containsAllSlice(&.{ 123, 789 }));

    // Test in-place operations
    try set.unionUpdate(testing.allocator, other);
    try expectEqual(set.cardinality(), 3);
    try expect(set.containsAllSlice(&.{ 123, 456, 789 }));
}

test "custom hash function with different load factors" {
    const context = TestContext{};

    // Test with low load factor
    var low_load = HashSetUnmanagedWithContext(u32, TestContext, 25).initContext(context);
    defer low_load.deinit(testing.allocator);

    // Test with high load factor
    var high_load = HashSetUnmanagedWithContext(u32, TestContext, 90).initContext(context);
    defer high_load.deinit(testing.allocator);

    // Add same elements to both
    for (0..100) |i| {
        _ = try low_load.add(testing.allocator, @intCast(i));
        _ = try high_load.add(testing.allocator, @intCast(i));
    }

    // Verify functionality is identical despite different load factors
    try expectEqual(low_load.cardinality(), high_load.cardinality());
    try expect(low_load.capacity() != high_load.capacity()); // Should be different due to load factors

    // Verify both sets contain the same elements
    for (0..100) |i| {
        const val: u32 = @intCast(i);
        try expect(low_load.contains(val) and high_load.contains(val));
    }
}

test "custom hash function error cases" {
    const context = TestContext{};
    var set = HashSetUnmanagedWithContext(u32, TestContext, 75).initContext(context);
    defer set.deinit(testing.allocator);

    // Test allocation failures
    var failing_allocator = std.testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, set.add(failing_allocator.allocator(), 123));
}

// String context for testing string usage with custom hash function
const StringContext = struct {
    pub fn hash(self: @This(), str: []const u8) u64 {
        _ = self;
        // Simple FNV-1a hash
        var h: u64 = 0xcbf29ce484222325;
        for (str) |b| {
            h = (h ^ b) *% 0x100000001b3;
        }
        return h;
    }

    pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
        _ = self;
        return std.mem.eql(u8, a, b);
    }
};

test "custom hash function string usage" {
    const context = StringContext{};
    var A = HashSetUnmanagedWithContext([]const u8, StringContext, 75).initContext(context);
    defer A.deinit(testing.allocator);

    var B = HashSetUnmanagedWithContext([]const u8, StringContext, 75).initContext(context);
    defer B.deinit(testing.allocator);

    _ = try A.add(testing.allocator, "Hello");
    _ = try B.add(testing.allocator, "World");

    var C = try A.unionOf(testing.allocator, B);
    defer C.deinit(testing.allocator);
    try expectEqual(2, C.cardinality());
    try expect(C.containsAllSlice(&.{ "Hello", "World" }));

    // Test string-specific behavior
    try expect(A.contains("Hello"));
    try expect(!A.contains("hello")); // Case sensitive
    try expect(!A.contains("Hell")); // Prefix doesn't match
    try expect(!A.contains("Hello ")); // Trailing space matters

    // Test with longer strings
    _ = try A.add(testing.allocator, "This is a longer string to test hash collisions");
    _ = try A.add(testing.allocator, "This is another longer string to test hash collisions");
    try expectEqual(3, A.cardinality());

    // Test with empty string
    _ = try A.add(testing.allocator, "");
    try expect(A.contains(""));
    try expectEqual(4, A.cardinality());

    // Test with strings containing special characters
    _ = try A.add(testing.allocator, "Hello\n");
    _ = try A.add(testing.allocator, "Hello\r");
    _ = try A.add(testing.allocator, "Hello\t");
    try expectEqual(7, A.cardinality());
}
