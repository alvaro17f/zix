const std = @import("std");

pub fn print(comptime fmt: []const u8, args: anytype) !void {
    var stdout_buf: [20]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;
    try stdout.print(fmt, args);
    try stdout.flush();
}
