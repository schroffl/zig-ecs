const std = @import("std");
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
