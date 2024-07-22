const std = @import("std");
const eql = std.mem.eql;
const print = std.debug.print;
const style = @import("style.zig").Style;

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

    print("{s}\n{s}\n* {s}{s}{s} *\n{s}\n{s}", .{ style.Blue, border, style.Red, text, style.Blue, border, style.Reset });
}

pub fn runCmd(output: bool, command: []const u8) !i32 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const shellCommand = [_][]const u8{ "sh", "-c", command };

    var cmd = std.process.Child.init(&shellCommand, allocator);

    if (output) {
        cmd.stdin_behavior = .Inherit;
        cmd.stdout_behavior = .Inherit;
        cmd.stderr_behavior = .Inherit;
    } else {
        cmd.stdin_behavior = .Ignore;
        cmd.stdout_behavior = .Ignore;
        cmd.stderr_behavior = .Ignore;
    }

    try cmd.spawn();

    if (output) {
        if (cmd.stdout) |stdout| {
            var stdout_stream = stdout.reader();
            while (try stdout_stream.readUntilDelimiterOrEofAlloc(allocator, '\n', 4096)) |line| {
                print("{s}\n", .{line});
            }
        }
    }

    const exit_status = try cmd.wait();

    return exit_status.Exited;
}

pub fn confirm(comptime default_value: bool, comptime msg: ?[]const u8) !bool {
    const default_value_str = if (default_value == true) std.fmt.comptimePrint("{s}(Y/n){s}", .{ style.Green, style.Reset }) else std.fmt.comptimePrint("{s}(y/N){s}", .{ style.Red, style.Reset });

    if (msg) |value| {
        _ = try std.io.getStdOut().write(std.fmt.comptimePrint("\n\n{s}{s}{s} {s}: ", .{ style.Yellow, value, style.Reset, default_value_str }));
    } else {
        _ = try std.io.getStdOut().write(std.fmt.comptimePrint("\n\n{s}Proceed?{s} {s}: ", .{ style.Yellow, style.Reset, default_value_str }));
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

pub fn boolToString(b: bool) []const u8 {
    return if (b) "true" else "false";
}
