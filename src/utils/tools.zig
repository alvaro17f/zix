const std = @import("std");
const eql = std.mem.eql;
const print = std.debug.print;

pub fn titleMaker(text: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const border = allocator.alloc(u8, text.len + 4) catch |err| {
        std.log.err("Failed to allocate memory: {}", .{err});
        return err;
    };

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

pub fn confirm(comptime default_value: bool, comptime msg: ?[]const u8) !bool {
    const default_value_str = if (default_value == true) "(Y/n)" else "(y/N)";

    if (msg) |value| {
        _ = try std.io.getStdOut().write(std.fmt.comptimePrint("\n\n{s} {s}: ", .{ value, default_value_str }));
    } else {
        _ = try std.io.getStdOut().write(std.fmt.comptimePrint("\n\nProceed? {s}: ", .{default_value_str}));
    }

    var buffer: [3]u8 = undefined;
    const response = try std.io.getStdIn().reader().readUntilDelimiterOrEof(&buffer, '\n') orelse "";
    if (eql(u8, response, "y") or eql(u8, response, "Y")) {
        return true;
    } else if (eql(u8, response, "n") or eql(u8, response, "N")) {
        return false;
    } else if (eql(u8, response, "\n") or eql(u8, response, "")) {
        return default_value;
    } else {
        return false;
    }
}
