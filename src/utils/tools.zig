const std = @import("std");
const allocator = @import("allocator").allocator;
const fmt = @import("fmt");
const eql = std.mem.eql;
const style = @import("style.zig");
const builtin = @import("builtin");

pub fn titleMaker(writer: *std.Io.Writer, text: []const u8) !void {
    const border = allocator.alloc(u8, text.len + 4) catch |err| {
        std.log.err("Failed to allocate memory: {}", .{err});
        return err;
    };
    defer allocator.free(border);
    for (border) |*c| {
        c.* = '*';
    }
    try fmt.printTo(writer, "{s}\n{s}\n* {s}{s}{s} *\n{s}\n{s}", .{ style.Blue, border, style.Red, text, style.Blue, border, style.Reset });
}

pub fn run(io: std.Io, command: []const u8, opts: struct { output: bool = true }) !i32 {
    const shellCommand = [_][]const u8{ "sh", "-c", command };
    var child = std.process.spawn(io, .{
        .argv = &shellCommand,
        .stdin = .inherit,
        .stdout = if (opts.output) .inherit else .ignore,
        .stderr = if (opts.output) .inherit else .ignore,
    }) catch |err| {
        std.log.err("Failed to spawn process: {}", .{err});
        return 1;
    };
    const term = child.wait(io) catch |err| {
        std.log.err("Failed to wait for process: {}", .{err});
        return 1;
    };
    switch (term) {
        .exited => |code| return code,
        else => return 1,
    }
}

pub fn confirm(reader: *std.Io.Reader, writer: *std.Io.Writer, comptime default_value: bool, comptime msg: ?[]const u8) !bool {
    const default_value_str = if (default_value == true)
        std.fmt.comptimePrint("{s}(Y/n){s}", .{ style.Green, style.Reset })
    else
        std.fmt.comptimePrint("{s}(y/N){s}", .{ style.Red, style.Reset });

    if (msg) |value| {
        try fmt.printTo(writer, "\n\n{s}{s}{s} {s}: ", .{ style.Yellow, value, style.Reset, default_value_str });
    } else {
        try fmt.printTo(writer, "\n\n{s}Proceed?{s} {s}: ", .{ style.Yellow, style.Reset, default_value_str });
    }

    const line = reader.takeDelimiterExclusive('\n') catch |err| {
        if (err == error.EndOfStream) {
            return default_value;
        }
        return err;
    };
    const response = std.ascii.allocLowerString(allocator, line) catch {
        return default_value;
    };
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

test "titleMaker border format" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try titleMaker(&writer, "ZIX");
    const s = std.mem.sliceTo(&buf, '\n');
    try std.testing.expect(s.len > 0);
}

test "confirm responses" {
    var wbuf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);

    const TestCase = struct {
        input: []const u8,
        default_value: bool,
        expected: bool,
    };
    const cases = &[_]TestCase{
        .{ .input = "y\n", .default_value = false, .expected = true },
        .{ .input = "yes\n", .default_value = false, .expected = true },
        .{ .input = "n\n", .default_value = true, .expected = false },
        .{ .input = "no\n", .default_value = true, .expected = false },
        .{ .input = "\n", .default_value = true, .expected = true },
        .{ .input = "\n", .default_value = false, .expected = false },
        .{ .input = "maybe\n", .default_value = true, .expected = false },
        .{ .input = "maybe\n", .default_value = false, .expected = false },
    };
    for (cases) |tc| {
        var reader = std.Io.Reader.fixed(tc.input);
        const result = try confirm(&reader, &writer, tc.default_value, null);
        try std.testing.expectEqual(tc.expected, result);
    }
}
