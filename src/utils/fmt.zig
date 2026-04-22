const std = @import("std");

pub fn printTo(writer: *std.Io.Writer, comptime format: []const u8, args: anytype) !void {
    try writer.print(format, args);
    try writer.flush();
}

test "printTo writes exact bytes" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try printTo(&writer, "hello {d} {s}", .{ 42, "world" });
    try std.testing.expectEqualStrings("hello 42 world", buf[0..14]);
}
