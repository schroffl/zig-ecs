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

pub fn formatSet(
    self: var,
    comptime fmt: []const u8,
    context: var,
    comptime Errors: type,
    output: fn (@typeOf(context), []const u8) Errors!void,
) Errors!void {
    try output(context, @typeName(@typeOf(self)));
    try output(context, "{");

    var first: bool = true;
    var iterator = self.iterate();

    while (iterator.next()) |item| {
        if (!first) try output(context, ", ");
        first = false;
        try std.fmt.formatType(item, "", context, Errors, output);
    }

    try output(context, "}");
}

const TestU = union(enum) {
    Signed16: i16,
    Unsigned32: u32,
};

test "Data" {
    comptime testing.expectEqual(i16, Data(TestU, .Signed16));
    comptime testing.expectEqual(u32, Data(TestU, .Unsigned32));
}

test "DataSize" {
    comptime testing.expectEqual(@sizeOf(i16) + @sizeOf(u32), DataSize(TestU));
}

test "DataOffset" {
    comptime testing.expectEqual(@sizeOf(i16), DataOffset(TestU, .Unsigned32));
}
