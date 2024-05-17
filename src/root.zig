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
/// Set is just a short convenient "default" alias. If you don't know
/// which to pick, just use Set.
pub const Set = HashSetManaged;

/// HashSetUnmanaged is a conveniently exported "unmanaged" version of a hash-based Set.
/// This Hash-based is optmized for lookups.
pub const HashSetUnmanaged = @import("hash_set/unmanaged.zig").HashSetUnmanaged;

/// HashSetManaged is a conveniently exported "managed" version of a hash_based Set.
pub const HashSetManaged = @import("hash_set/managed.zig").HashSetManaged;

/// ArraySetUnmanaged is a conveniently exported "unmanaged" version of an array-based Set.
/// This is a bit more specialized and optimized for heavy iteration.
pub const ArraySetUnmanaged = @import("array_hash_set/unmanaged.zig").ArraySetUnmanaged;

/// ArraySetManaged is a conveniently exported "managed" version of an array-based Set.
pub const ArraySetManaged = @import("array_hash_set/managed.zig").ArraySetManaged;
