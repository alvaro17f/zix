pub const Red = "\x1b[31m";
pub const Green = "\x1b[32m";
pub const Yellow = "\x1b[33m";
pub const Blue = "\x1b[34m";
pub const Magenta = "\x1b[35m";
pub const Cyan = "\x1b[36m";
pub const Gray = "\x1b[37m";
pub const Black = "\x1b[30m";
pub const Reset = "\x1b[0m";
pub const Bold = "\x1b[1m";
pub const Underline = "\x1b[4m";

test "style constants are non-empty" {
    const std = @import("std");
    const fields = @typeInfo(@This()).@"struct".fields;
    inline for (fields) |field| {
        const val = @field(@This(), field.name);
        try std.testing.expect(val.len > 0);
    }
}
