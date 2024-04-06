const std = @import("std");
const print = std.debug.print;

pub fn titleMaker(text: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var border = try allocator.alloc(u8, text.len + 4);

    for (border) |*c| {
        c.* = '*';
    }

    print("\n{s}\n* {s} *\n{s}\n", .{ border, text, border });
}

pub fn runCmd(command: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const shellCommand = [_][]const u8{ "sh", "-c", command };

    var cmd = std.ChildProcess.init(&shellCommand, allocator);

    cmd.stdin_behavior = .Inherit;
    cmd.stdout_behavior = .Inherit;
    cmd.stderr_behavior = .Inherit;

    try cmd.spawn();

    if (cmd.stdout) |stdout| {
        var stdout_stream = stdout.reader();
        while (try stdout_stream.readUntilDelimiterOrEofAlloc(allocator, '\n', 4096)) |line| {
            print("{s}\n", .{line});
        }
    } else {}

    // TODO: handle exit status
    _ = try cmd.wait();
}
