const std = @import("std");
const util = @import("util.zig");

fn getByte(n: usize) usize {
    // This is a faster version of
    // std.math.floor(@intToFloat(f32, n) / 8);
    return n >> 3;
}

fn getBitOffset(n: usize) u3 {
    return @intCast(u3, n & 7);
}

fn setBit(bytes: var, bit: usize) void {
    const offset = getByte(bit);
    const idx = getBitOffset(bit);

    bytes[offset] |= (u8(1) << idx);
}

fn clearBit(bytes: var, bit: usize) void {
    const offset = getByte(bit);
    const idx = getBitOffset(bit);

    bytes[offset] &= ~(u8(1) << idx);
}

fn checkBit(bytes: var, bit: usize) bool {
    const offset = getByte(bit);
    const idx = getBitOffset(bit);

    return (bytes[offset] & (u8(1) << idx)) != 0;
}

/// A Bit Set with a compile-time known size.
pub fn FixedBits(comptime capacity: usize) type {
    const data_size = getByte(capacity) + 1;

    return struct {
        const Self = @This();

        data: [data_size]u8,

        /// Create a new Set with all bits
        /// initialized to 0 (unset)
        pub fn init() Self {
            return Self{ .data = []u8{0} ** data_size };
        }

        /// Add a new element to the set
        pub fn add(self: *Self, bit: usize) void {
            std.debug.assert(bit <= capacity);
            setBit(&self.data, bit);
        }

        /// Remove an element from the set
        pub fn delete(self: *Self, bit: usize) void {
            std.debug.assert(bit <= capacity);
            clearBit(&self.data, bit);
        }

        /// Check whether a given element is in a set
        pub fn has(self: Self, bit: usize) bool {
            std.debug.assert(bit <= capacity);
            return checkBit(&self.data, bit);
        }

        /// The function is called unionize, because union is a reserved
        /// keyword...
        pub fn unionize(a: *Self, b: Self) void {
            var i: usize = 0;
            while (i < data_size) : (i += 1) a.data[i] |= b.data[i];
        }

        /// TODO Write doc comments
        pub fn subtract(a: *Self, b: Self) void {
            var i: usize = 0;
            while (i < data_size) : (i += 1) a.data[i] &= ~b.data[i];
        }

        /// TODO Write doc comments
        pub fn empty(self: *Self) void {
            std.mem.secureZero(u8, self.data[0..]);
        }

        /// TODO Write doc comments
        pub fn iterate(self: *const Self) Iterator {
            return Iterator{
                .set = self,
                .count = 0,
            };
        }

        pub const Iterator = struct {
            set: *const Self,
            count: usize,

            pub fn next(it: *Iterator) ?usize {
                return while (it.count <= capacity) {
                    const val = it.count;
                    it.count += 1;
                    if (it.set.has(val)) break val;
                } else return null;
            }
        };

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            context: var,
            comptime Errors: type,
            output: fn (@typeOf(context), []const u8) Errors!void,
        ) Errors!void {
            try util.formatSet(self, fmt, context, Errors, output);
        }
    };
}

test "FixedBits" {
    var bits = FixedBits(25).init();

    std.testing.expectEqual(4, bits.data.len);

    std.testing.expect(!bits.has(17));
    bits.add(17);
    std.testing.expect(bits.has(17));
    bits.empty();
    std.testing.expect(!bits.has(17));
}

test "FixedBits.unionize" {
    const S = FixedBits(8);
    var a = S.init();
    var b = S.init();

    a.add(5);
    b.add(2);
    b.add(5);
    S.unionize(&a, b);
    std.testing.expect(a.has(5) and a.has(2));
    std.testing.expectEqual(u8(0b100100), a.data[0]);
}

/// A Bit Set that will dynamically allocate memory
/// to accompany all elements.
///
/// TODO I'm not entirely sure whether the implementation
/// does proper memory management. I'll have to check
/// that at some point.
pub const Bits = struct {
    allocator: *std.mem.Allocator,
    data: []u8,
    max_value: ?usize,

    /// TODO Write doc comments
    pub fn init(allocator: *std.mem.Allocator) Bits {
        return Bits{
            .allocator = allocator,
            .data = []u8{},
            .max_value = null,
        };
    }

    /// TODO Write doc comments
    pub fn deinit(self: Bits) void {
        self.allocator.free(self.data);
    }

    /// TODO Write doc comments
    pub fn add(self: *Bits, bit: usize) !void {
        const required = getByte(bit) + 1;
        if (required > self.data.len) try util.ensureCapacity(self, required);

        if (self.max_value) |max| {
            if (bit > max) self.max_value = bit;
        } else {
            self.max_value = bit;
        }

        setBit(self.data, bit);
    }

    /// TODO Write doc comments
    pub fn delete(self: *Bits, bit: usize) void {
        const required = getByte(bit) + 1;
        if (required > self.data.len) return;
        clearBit(self.data, bit);
    }

    pub fn has(self: Bits, bit: usize) bool {
        const required = getByte(bit) + 1;
        if (required > self.data.len) return false;
        return checkBit(self.data, bit);
    }

    fn ensureCapacity(self: *Bits, new_capacity: usize) !void {
        if (new_capacity == 0) {
            self.allocator.free(self.data);
        } else if (self.max_value == null) {
            self.data = try self.allocator.alloc(u8, new_capacity);
            std.mem.secureZero(u8, self.data);
        } else {
            const old_capacity = self.data.len;
            self.data = try self.allocator.realloc(self.data, new_capacity);

            if (new_capacity > old_capacity)
                std.mem.secureZero(u8, self.data[old_capacity..]);
        }
    }

    /// TODO Write doc comments
    pub fn shrink(self: *Bits) !void {
        if (self.max_value == null) return;

        var i: usize = 0;
        var highest_bit: usize = 0;

        while (i < self.max_value.?) : (i += 1) {
            if (self.has(i)) highest_bit = i;
        }

        if (highest_bit == 0 and !self.has(0)) {
            self.max_value = null;
            try self.ensureCapacity(0);
        } else {
            try self.ensureCapacity(getByte(highest_bit) + 1);
        }
    }

    /// TODO Write doc comments
    pub fn iterate(self: *const Bits) Iterator {
        return Iterator{
            .set = self,
            .count = 0,
        };
    }

    pub const Iterator = struct {
        set: *const Bits,
        count: usize,

        pub fn next(it: *Iterator) ?usize {
            if (it.set.max_value == null) return null;

            return while (it.count <= it.set.max_value.?) {
                const val = it.count;
                it.count += 1;
                if (it.set.has(val)) break val;
            } else return null;
        }
    };

    pub fn format(
        self: Bits,
        comptime fmt: []const u8,
        context: var,
        comptime Errors: type,
        output: fn (@typeOf(context), []const u8) Errors!void,
    ) Errors!void {
        try util.formatSet(self, fmt, context, Errors, output);
    }
};

test "Bits" {
    var bits = Bits.init(std.debug.global_allocator);

    std.testing.expect(bits.data.len == 0);
    std.testing.expect(!bits.has(100));
    std.testing.expect(!bits.has(9999999999));
    try bits.add(100);
    std.testing.expect(bits.has(100));
    bits.delete(100);
    std.testing.expect(!bits.has(100));

    try bits.shrink();
    std.testing.expect(!bits.has(42));
    bits.delete(42);
    try bits.add(42);
    std.testing.expect(bits.has(42));
}
