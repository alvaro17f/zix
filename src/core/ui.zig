const std = @import("std");
const io = @import("io.zig");
const eql = std.mem.eql;

pub fn printTitle(writer: *std.Io.Writer, text: []const u8, alloc: std.mem.Allocator) !void {
    const border = alloc.alloc(u8, text.len + 4) catch |err| {
        std.log.err("Failed to allocate memory: {}", .{err});
        return err;
    };
    defer alloc.free(border);
    for (border) |*c| {
        c.* = '*';
    }
    try io.printTo(writer, "{s}\n{s}\n* {s}{s}{s} *\n{s}\n{s}", .{ io.Blue, border, io.Red, text, io.Blue, border, io.Reset });
}

pub fn confirm(reader: *std.Io.Reader, writer: *std.Io.Writer, default_value: bool, msg: ?[]const u8, alloc: std.mem.Allocator) !bool {
    _ = reader;
    return confirmStdin(writer, default_value, msg, alloc);
}

fn writeConfirmPrompt(writer: *std.Io.Writer, default_value: bool, msg: ?[]const u8) !void {
    const hint = if (default_value) std.fmt.comptimePrint("{s}(Y/n){s}", .{ io.Green, io.Reset }) else std.fmt.comptimePrint("{s}(y/N){s}", .{ io.Red, io.Reset });
    if (msg) |value| {
        try io.printTo(writer, "{s}{s}{s} {s}: ", .{ io.Yellow, value, io.Reset, hint });
    } else {
        try io.printTo(writer, "\n\n{s}Proceed?{s} {s}: ", .{ io.Yellow, io.Reset, hint });
    }
    try writer.flush();
}

fn parseConfirmResponse(line: []const u8, default_value: bool, alloc: std.mem.Allocator) !bool {
    const response = std.ascii.allocLowerString(alloc, line) catch return default_value;
    defer alloc.free(response);
    if (eql(u8, response, "y") or eql(u8, response, "yes")) return true;
    if (eql(u8, response, "n") or eql(u8, response, "no")) return false;
    if (eql(u8, response, "") or line.len == 0) return default_value;
    return false;
}

fn confirmStdin(writer: *std.Io.Writer, default_value: bool, msg: ?[]const u8, alloc: std.mem.Allocator) !bool {
    try writeConfirmPrompt(writer, default_value, msg);

    var buf: [256]u8 = undefined;
    var i: usize = 0;
    while (i < buf.len - 1) {
        const n = std.posix.read(0, buf[i..i+1]) catch |err| {
            if (err == error.WouldBlock) continue;
            return err;
        };
        if (n == 0) return false;
        if (buf[i] == '\n') return parseConfirmResponse(buf[0..i], default_value, alloc);
        i += 1;
    }
    return false;
}

pub fn confirmAlloc(reader: *std.Io.Reader, writer: *std.Io.Writer, default_value: bool, msg: ?[]const u8, alloc: std.mem.Allocator) !bool {
    try writeConfirmPrompt(writer, default_value, msg);

    const line = reader.takeDelimiterExclusive('\n') catch |err| {
        if (err == error.EndOfStream) return false;
        return err;
    };
    return parseConfirmResponse(line, default_value, alloc);
}

test "printTitle border format" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try printTitle(&writer, "ZIX", std.testing.allocator);
    const s = std.mem.sliceTo(&buf, '\n');
    try std.testing.expect(s.len > 0);
}

test "printTitle alloc failure" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    var fa = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const fa_alloc = fa.allocator();
    try std.testing.expectError(error.OutOfMemory, printTitle(&writer, "ZIX", fa_alloc));
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
        const result = try confirmAlloc(&reader, &writer, tc.default_value, tc.msg, std.testing.allocator);
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
