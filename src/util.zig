const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");
const assert = std.debug.assert;
const trait = std.meta.trait;

/// TODO Write doc comments
pub fn Data(comptime U: type, comptime Tag: @TagType(U)) type {
    const tag_value = @enumToInt(Tag);
    const fields = comptime std.meta.fields(@TagType(U));

    return for (fields) |field, i| {
        if (field.value == tag_value) break @memberType(U, i);
    };
}

/// TODO Write doc comments
pub fn DataSize(comptime U: type) usize {
    var size: usize = 0;

    for (std.meta.fields(U)) |field| size += @sizeOf(field.field_type);

    return size;
}

/// TODO Write doc comments
pub fn DataOffset(comptime U: type, comptime Tag: @TagType(U)) usize {
    const fields = comptime std.meta.fields(@TagType(U));
    var offset: usize = 0;

    return for (fields) |field, i| {
        if (@intToEnum(@TagType(U), field.value) == Tag) break offset;
        offset += @sizeOf(@memberType(U, i));
    };
}

/// TODO Write doc comments
pub fn ensureCapacity(of: var, capacity: usize) !void {
    const adjusted = @intToFloat(f32, capacity + 1) * 1.5;
    try of.ensureCapacity(@floatToInt(usize, adjusted));
}

const TestU = union(enum) {
    Signed16: i16,
    Unsigned32: u32,
};

test "Data" {
    comptime testing.expectEqual(Data(TestU, .Signed16), i16);
    comptime testing.expectEqual(Data(TestU, .Unsigned32), u32);
}

test "DataSize" {
    comptime testing.expectEqual(DataSize(TestU), @sizeOf(i16) + @sizeOf(u32));
}

test "DataOffset" {
    comptime testing.expectEqual(DataOffset(TestU, .Unsigned32), @sizeOf(i16));
}
