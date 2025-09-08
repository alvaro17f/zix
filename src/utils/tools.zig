const std = @import("std");
const allocator = @import("allocator").allocator;
const fmt = @import("fmt");
const eql = std.mem.eql;
const style = @import("style.zig");
const builtin = @import("builtin");

pub fn titleMaker(text: []const u8) !void {
    const border = allocator.alloc(u8, text.len + 4) catch |err| {
        std.log.err("Failed to allocate memory: {}", .{err});
        return err;
    };

    defer allocator.free(border);

    for (border) |*c| {
        c.* = '*';
    }

    try fmt.print("{s}\n{s}\n* {s}{s}{s} *\n{s}\n{s}", .{ style.Blue, border, style.Red, text, style.Blue, border, style.Reset });
}

pub fn run(command: []const u8, opts: struct { output: bool = true }) !i32 {
    const shellCommand = [_][]const u8{ "sh", "-c", command };

    var cmd = std.process.Child.init(&shellCommand, allocator);

    const isOutputEnabled: std.process.Child.StdIo = if (opts.output) .Inherit else .Ignore;

    cmd.stdin_behavior = isOutputEnabled;
    cmd.stdout_behavior = isOutputEnabled;
    cmd.stderr_behavior = isOutputEnabled;

    try cmd.spawn();

    if (opts.output) {
        if (cmd.stdout) |stdout| {
            var stdout_buf: [4096]u8 = undefined;
            var stdout_stream = stdout.readerStreaming(&stdout_buf);
            const cmd_stdout = &stdout_stream.interface;
            const line = try cmd_stdout.takeDelimiterExclusive('\n');
            for (line) |l| {
                try fmt.print("{}\n", .{l});
            }
        }
    }

    const exit_status = try cmd.wait();

    return exit_status.Exited;
}

pub fn confirm(comptime default_value: bool, comptime msg: ?[]const u8) !bool {
    const default_value_str = if (default_value == true) std.fmt.comptimePrint("{s}(Y/n){s}", .{ style.Green, style.Reset }) else std.fmt.comptimePrint("{s}(y/N){s}", .{ style.Red, style.Reset });

    if (msg) |value| {
        _ = try fmt.print("\n\n{s}{s}{s} {s}: ", .{ style.Yellow, value, style.Reset, default_value_str });
    } else {
        _ = try fmt.print("\n\n{s}Proceed?{s} {s}: ", .{ style.Yellow, style.Reset, default_value_str });
    }

    var stdin_buf: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
    const stdin = &stdin_reader.interface;
    const line = try stdin.takeDelimiterExclusive('\n');
    const response = try std.ascii.allocLowerString(allocator, line);
    defer allocator.free(response);

    if (eql(u8, response, "y") or eql(u8, response, "yes")) {
        return true;
    } else if (eql(u8, response, "n") or eql(u8, response, "no")) {
        return false;
    } else if (eql(u8, response, "\n") or eql(u8, response, "")) {
        return default_value;
    } else {
        return false;
    }
}
