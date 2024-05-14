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

// comptime selection of the map type for string vs everything else.
fn selectMap(comptime E: type) type {
    comptime {
        if (E == []const u8) {
            return std.StringHashMapUnmanaged(void);
        } else {
            return std.AutoHashMapUnmanaged(E, void);
        }
    }
}

pub fn SetUnmanaged(comptime E: type) type {
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

        /// Cardinality effectively returns the size of the set.
        pub fn cardinality(self: Self) Size {
            return self.unmanaged.count();
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

        pub fn isEmpty(self: Self) bool {
            return self.unmanaged.count() == 0;
        }

        /// Create an iterator over the elements in the set.
        /// The iterator is invalidated if the set is modified during iteration.
        pub fn iterator(self: Self) Iterator {
            return self.unmanaged.keyIterator();
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
    var A = SetUnmanaged(u32).init();
    defer A.deinit(testing.allocator);

    // Add some data
    _ = try A.add(testing.allocator, 5);
    _ = try A.add(testing.allocator, 6);
    _ = try A.add(testing.allocator, 7);

    // Add more data; single shot, duplicate data is ignored.
    _ = try A.appendSlice(testing.allocator, &.{ 5, 3, 0, 9 });

    // Create another set called B
    var B = SetUnmanaged(u32).init();
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
