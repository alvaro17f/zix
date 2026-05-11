const std = @import("std");
const fmt = @import("fmt.zig");
const eql = std.mem.eql;
const style = @import("style.zig");

pub const RunOpts = struct { output: bool = true };

pub fn printTitle(writer: *std.Io.Writer, text: []const u8, alloc: std.mem.Allocator) !void {
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

pub fn run(io: std.Io, command: []const u8, opts: RunOpts) !i32 {
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

pub fn confirm(reader: *std.Io.Reader, writer: *std.Io.Writer, default_value: bool, msg: ?[]const u8, alloc: std.mem.Allocator) !bool {
    _ = reader;
    return confirmStdin(writer, default_value, msg, alloc);
}

fn writeConfirmPrompt(writer: *std.Io.Writer, default_value: bool, msg: ?[]const u8) !void {
    const hint = if (default_value) std.fmt.comptimePrint("{s}(Y/n){s}", .{ style.Green, style.Reset }) else std.fmt.comptimePrint("{s}(y/N){s}", .{ style.Red, style.Reset });
    if (msg) |value| {
        try fmt.printTo(writer, "\n\n{s}{s}{s} {s}: ", .{ style.Yellow, value, style.Reset, hint });
    } else {
        try fmt.printTo(writer, "\n\n{s}Proceed?{s} {s}: ", .{ style.Yellow, style.Reset, hint });
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
