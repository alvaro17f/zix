const std = @import("std");
const allocator = @import("allocator.zig").allocator;
const fmt = @import("fmt.zig");
const eql = std.mem.eql;
const style = @import("style.zig");
const builtin = @import("builtin");

pub fn titleMaker(writer: *std.Io.Writer, text: []const u8) !void {
    return titleMakerAlloc(writer, text, allocator);
}

pub fn titleMakerAlloc(writer: *std.Io.Writer, text: []const u8, alloc: std.mem.Allocator) !void {
    const border = alloc.alloc(u8, text.len + 4) catch |err| {
        std.log.err("Failed to allocate memory: {}", .{err});
        return err;
    };
    defer alloc.free(border);
    for (border) |*c| {
        c.* = '*';
    }
    try fmt.printTo(writer, "{s}\n{s}\n* {s}{s}{s} *\n{s}\n{s}", .{ style.Blue, border, style.Red, text, style.Blue, border, style.Reset });
}

pub fn run(io: std.Io, command: []const u8, opts: @import("../app/cli.zig").RunOpts) !i32 {
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

pub fn confirm(reader: *std.Io.Reader, writer: *std.Io.Writer, default_value: bool, msg: ?[]const u8) !bool {
    return confirmAlloc(reader, writer, default_value, msg, allocator);
}

pub fn confirmAlloc(reader: *std.Io.Reader, writer: *std.Io.Writer, default_value: bool, msg: ?[]const u8, alloc: std.mem.Allocator) !bool {
    const default_value_str = if (default_value == true)
        std.fmt.comptimePrint("{s}(Y/n){s}", .{ style.Green, style.Reset })
    else
        std.fmt.comptimePrint("{s}(y/N){s}", .{ style.Red, style.Reset });

    if (msg) |value| {
        try fmt.printTo(writer, "\n\n{s}{s}{s} {s}: ", .{ style.Yellow, value, style.Reset, default_value_str });
    } else {
        try fmt.printTo(writer, "\n\n{s}Proceed?{s} {s}: ", .{ style.Yellow, style.Reset, default_value_str });
    }
    try writer.flush();

    const line = reader.takeDelimiterExclusive('\n') catch |err| {
        if (err == error.EndOfStream) {
            return false;
        }
        return err;
    };
    const response = std.ascii.allocLowerString(alloc, line) catch {
        return default_value;
    };
    defer alloc.free(response);

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

test "titleMaker alloc failure" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    var fa = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const fa_alloc = fa.allocator();
    try std.testing.expectError(error.OutOfMemory, titleMakerAlloc(&writer, "ZIX", fa_alloc));
}

test "run basic commands" {
    const io = std.testing.io;
    try std.testing.expectEqual(@as(i32, 0), try run(io, "true", .{}));
    try std.testing.expectEqual(@as(i32, 1), try run(io, "false", .{}));
    try std.testing.expectEqual(@as(i32, 1), try run(io, "kill -9 $$", .{}));
    try std.testing.expectEqual(@as(i32, 0), try run(io, "", .{ .output = false }));
}

test "confirm responses" {
    const TestCase = struct {
        input: []const u8,
        default_value: bool,
        expected: bool,
        msg: ?[]const u8 = null,
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
        .{ .input = "", .default_value = true, .expected = false },
        .{ .input = "y\n", .default_value = false, .expected = true, .msg = "Sure" },
    };
    inline for (cases) |tc| {
        var wbuf: [512]u8 = undefined;
        var writer = std.Io.Writer.fixed(&wbuf);
        var reader = std.Io.Reader.fixed(tc.input);
        const result = try confirm(&reader, &writer, tc.default_value, tc.msg);
        try std.testing.expectEqual(tc.expected, result);
    }
}

test "confirm alloc failure" {
    var wbuf: [512]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("y\n");
    var fa = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const result = try confirmAlloc(&reader, &writer, true, null, fa.allocator());
    try std.testing.expectEqual(true, result);
}
