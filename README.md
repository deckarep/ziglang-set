### Ziglang Set

<p align="center">
Ziglang-Set: a generic and general-purpose Set implementation for Zig. <br/> 🚧 PRE-ALPHA 🚧
</p>

#

<p align="center">
  <img src="assets/ZigSetGraphic.png" width="512"/>
</p>

#

Zig currently [does not have](https://github.com/ziglang/zig/issues/6919) a built-in, general purpose Set data structure at this point in time. Until it does, try this!

#

This module offers a Set implementation built in the same vein and spirit of the other data structures within the Zig standard library. This is my attempt to model one that can get better over time and grow with community interest and support. See a problem, file a bug! Or better yet contribute and let's build the best implementation together.

I am the original author of the popular Go based set package: [golang-set](https://github.com/deckarep/golang-set) that is used by software components built by Docker, 1Password, Ethereum, SendGrid, CrowdStrike and HashiCorp. At just shy of `4k stars`, I figured I'd take a crack at building a comprehensive and generic Zig-based set that goes above and beyond the original Go implementation. After using Zig for over 2.5 years on personal projects, I thought it was time that Zig had a robust Set implementation for itself.

This implementation gives credit and acknowledgement to the [Zig language](https://ziglang.org) and powerful [Std Library](https://ziglang.org/documentation/master/std/#std) [HashMap](https://ziglang.org/documentation/master/std/#std.hash_map.HashMap) data structure of which this set implementation is built on top of. Without that, this probably wouldn't exist. Efforts will be made to keep the Ziglang Set code fast and straightforward but this Set's raw speed will largely be bounded by the performance of the Zig HashMap of which it is built on top of.

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
  * Fully documented and robustly tested - in progress
  * Performance aware to minimize unecessary allocs/iteration internally
  * "string" support - coming soon
  * Benchmarks - coming soon
#
#### Why use a set?
  * A set offers a fast way to manipulate data and avoid excessive looping. Look into it as there is already tons of literature on the advantages of having a set in your arsenal of tools.
#
#### Example
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

#

#### Installation of Module

To add this module, update your applications build.zig.zon file by adding the `.ziglang-set` dependency definition. 

```zig
.{
    .name = "your-app",
    .version = "0.1.0",
    .dependencies = .{
        .ziglang-set = .{
            .url = "https://github.com/deckarep/ziglang-set/archive/$COMMIT_YOU_WANT_TO_USE.tar.gz",
        },
    },
}
```

When running zig build now, Zig will tell you you need a hash for the dependency and provide one.
Put it in your dependency so it looks like:

```zig
.{
  .ziglang-set = .{
      .url = "https://github.com/deckarep/ziglang-set/archive/$COMMIT_YOU_WANT_TO_USE.tar.gz",
      .hash = "$HASH_ZIG_GAVE_YOU",
  },
}
```

With the dependency in place, you can now put the following in your build.zig file:

```zig
    // This will create a `std.build.Dependency` which you can use to fetch
    // the `ziglang-set` module. The first argument is the dependency name. It
    // should be the same as the one you used in build.zig.zon.
    const ziglangSet = b.dependency("ziglang-set", .{});
    // This will create a module which you can use in your zig code. The first
    // argument is the name you want your module to have in your zig code. It
    // can be anything you want. In your zig code you can use `@import` with
    // the same name to use it. The second argument is a module. You can
    // fetch it from the dependency with its `module` method. This method
    // takes one argument which is the name of the module. This time, the
    // name is the one the `ziglang-set` package uses. It must be exactly the
    // same string as below: "ziglang-set". The reason for needing this name is
    // that some packages can expose multiple modules. Therefor, you need to
    // specify which one you want. This package only exposes one module though,
    // so it will always be the same.
    exe.addModule("ziglang-set", ziglangSet.module("ziglang-set"));
```

In the above change `exe` to whatever CompileStep you are using. For an executable it will
probably be exe, but `main_tests` or lib are also common.

With the build file in order, you can now use the module in your zig source. For example:

```zig
const std = @import("std");
const set = @import("ziglang-set");

pub fn main() void {
    // 1. This datastructure requires an allocator.
    //    Setup and choose your respective allocator.
    // See: https://zig.guide/standard-library/allocators

    // 2. Go to town!
    var A = Set(u32).init(allocator);
    defer A.deinit();

    // Now do something cool with your set!
    // ...
}
```

Check the tests for more comprehensive examples on how to use this package.

#### Testing

```sh
zig build test
```
