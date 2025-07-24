const std = @import("std");

pub fn print(comptime fmt: []const u8, args: anytype) !void {
    const stdout = std.io.getStdOut();
    const writer = stdout.writer();
    try writer.print(fmt, args);
    // try writer.flush();
}
