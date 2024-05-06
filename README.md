### Ziglang Set

<p align="center">
Ziglang-Set: a generic and general-purpose Set implementation.
</p>

#

<p align="center">
  <img src="assets/ZigSetGraphic.png" width="512"/>
</p>

#

Zig currently doesn't have a built-in, general purpose Set data structure at this point in time. *Until it does, use this!* This module offers a fast Set implementation built in the same vein and spirit of the other data structures in the Zig standard library. This is my attempt to model one that can get better over time and grow with community interest and support. See a problem, file a bug! Or better yet contribute and let's build the best implementation together.

I am the original author of the popular Go based set package: [golang-set](https://github.com/deckarep/golang-set) that is used by software components built by Docker, 1Password, Ethereum, SendGrid, CrowdStrike and HashiCorp. At just shy of 4k stars, I figured I'd take a crack at building a comprehensive and generic Zig-based set that goes above and beyond the original Go implementation. Perhaps I'm not the best qualified to do this but I have been using Zig off and on for personal projects for about 2.5 years and I absolutely love the language.

This implementation gives credit and acknowledgement to the [Zig language](https://ziglang.org) and powerful [Std Library](https://ziglang.org/documentation/master/std/#std) [HashMap](https://ziglang.org/documentation/master/std/#std.hash_map.HashMap) data structure of which this set implementation is built on top of. Without that, this probably wouldn't exist.
Furthermore, my intention is to build a general-purpose and performant Zig module that can grow with the community and offers idiomatic and expected Zig code even though this implementation is inspired by the Go implementation (which was inspired by the Python implementation prior).
#
#### Features
  * Offers idiomatic, generic-based Zig API - allocators, iterators, capacity hints, clearing, resizing, etc.
  * Common set operations
    * add, append, appendSlice
    * remove, removeAll
    * containsOne, containsAny, containsAll
    * clone, cloneWithAllocator
    * equals, isEmpty, cardinality
    * intersection, intersectionUpdate (in-place variant)
    * union, unionUpdate (in-place variant)
    * difference, differenceUpdate (in-place variant)
    * symmetricDifference, symmetricDifferenceUpdate (in-place variant)
    * isSubset
    * isSuperset
    * isProperSubset
    * isProperSuperset
    * pop
  * Fully documented and robustly tested (how all software should be) - coming soon
  * Performance aware to minimize unecessary allocs/iteration internally
  * String support - coming soon
  * Benchmarks - coming soon
#
#### Why use a set?
  * A set offers a fast way to manipulate data and avoid excessive looping. Look into it as there is already tons of literature on the advantages of having a set in your arsenal of tools.
#
#### Usage
```zig
    // import the namespace.
    const set = @import("set.zig");

    // Create a set of u32s called A
    var A = Set(u32).init(std.testing.allocator);
    defer A.deinit();

    // Add some data
    _ = try A.add(5);
    _ = try A.add(6);
    _ = try A.add(7);

    // Add more data; single shot, duplicate data is ignored.
    _ = try A.appendSlice(&.{ 5, 3, 0, 9 });

    // Create another set called B
    var B = Set(u32).init(std.testing.allocator);
    defer B.deinit();

    // Add data to B
    _ = try B.appendSlice(&.{ 50, 30, 20 });

    // Get the union of A | B
    var un = try A.unionOf(B);
    defer un.deinit();

    // Grab an iterator and dump the contents.
    var iter = un.iterator();
    while (iter.next()) |el| {
        std.log.debug("element: {d}", .{el.*});
    }
```
#

Output of `A | B` - the union of A and B (order is not guaranteed)
```sh
> element: 5
> element: 6
> element: 7
> element: 3
> element: 0
> element: 9
> element: 50
> element: 30
> element: 20
```