const std = @import("std");

pub const RunOpts = struct { output: bool = true };

pub fn run(io: std.Io, command: []const u8, opts: RunOpts) !i32 {
    // Assert preconditions: command must not be empty.
    std.debug.assert(command.len > 0);

    const shellCommand = [_][]const u8{ "sh", "-c", command };
    var child = try std.process.spawn(io, .{
        .argv = &shellCommand,
        .stdin = .inherit,
        .stdout = if (opts.output) .inherit else .ignore,
        .stderr = if (opts.output) .inherit else .ignore,
    });
    const term = try child.wait(io);
    switch (term) {
        .exited => |code| return code,
        else => return 1,
    }
}

test "run basic commands" {
    const io = std.testing.io;
    try std.testing.expectEqual(@as(i32, 0), try run(io, "true", .{}));
    try std.testing.expectEqual(@as(i32, 1), try run(io, "false", .{}));
    try std.testing.expectEqual(@as(i32, 1), try run(io, "kill -9 $$", .{}));
    try std.testing.expectEqual(@as(i32, 0), try run(io, "", .{ .output = false }));
}
