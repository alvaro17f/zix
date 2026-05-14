const std = @import("std");
const io = @import("io.zig");
const eql = std.mem.eql;

// --- Title ---

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

// --- Help / Version ---

pub fn printHelp(writer: *std.Io.Writer) !void {
    try io.printTo(writer,
        \\
        \\ *****************************************************
        \\  ZIX - A simple CLI tool to update your nixos system
        \\ *****************************************************
        \\ -r : set repo path (default is $HOME/.dotfiles)
        \\ -n : set hostname (default is OS hostname)
        \\ -k : set generations to keep (default is 10)
        \\ -u : set update to true (default is false)
        \\ -d : set diff to true (default is false)
        \\ -h, help : Display this help message
        \\ -v, version : Display the current version
        \\
        \\
    , .{});
}

pub fn printVersion(writer: *std.Io.Writer, version: []const u8) !void {
    try io.printTo(writer, "{s}\nZIX version: {s}{s}\n{s}", .{ io.Yellow, io.Cyan, version, io.Reset });
}

// --- Config Printing ---

fn printConfigLine(writer: *std.Io.Writer, label: []const u8, value: anytype, options: struct { new_line: bool = true }) !void {
    const value_fmt = comptime if (@TypeOf(value) == []const u8) "{" ++ "s}" else "{" ++ "}";
    try io.printTo(writer, "{s}◉ {s}{s}{s} = {s}" ++ value_fmt ++ "{s}{s}", .{
        io.Cyan,
        io.Red,
        label,
        io.Reset,
        io.Cyan,
        value,
        io.Reset,
        if (options.new_line) "\n" else "",
    });
}

pub fn configPrint(writer: *std.Io.Writer, config: @import("../app/config.zig").Config) !void {
    const fields = @typeInfo(@TypeOf(config)).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        const is_last = i == fields.len - 1;
        const value = @field(config, field.name);
        try printConfigLine(writer, field.name, value, .{ .new_line = !is_last });
    }
}

// --- Confirm ---

pub fn confirm(writer: *std.Io.Writer, default_value: bool, msg: ?[]const u8, alloc: std.mem.Allocator) !bool {
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

fn writeConfirmPrompt(writer: *std.Io.Writer, default_value: bool, msg: ?[]const u8) !void {
    const hint = if (default_value) std.fmt.comptimePrint("{s}(Y/n){s}", .{ io.Green, io.Reset }) else std.fmt.comptimePrint("{s}(y/N){s}", .{ io.Red, io.Reset });
    if (msg) |value| {
        try io.printTo(writer, "\n{s}{s}{s} {s}: ", .{ io.Yellow, value, io.Reset, hint });
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

pub fn confirmAlloc(reader: *std.Io.Reader, writer: *std.Io.Writer, default_value: bool, msg: ?[]const u8, alloc: std.mem.Allocator) !bool {
    try writeConfirmPrompt(writer, default_value, msg);

    const line = reader.takeDelimiterExclusive('\n') catch |err| {
        if (err == error.EndOfStream) return false;
        return err;
    };
    return parseConfirmResponse(line, default_value, alloc);
}

// --- Tests ---

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

test "printHelp writes help text" {
    var buf: [2048]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try printHelp(&writer);
    const out = std.mem.sliceTo(&buf, 0);
    try std.testing.expect(std.mem.indexOf(u8, out, "ZIX") != null);
}

test "printVersion writes version" {
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try printVersion(&writer, "1.0.0");
    const out = std.mem.sliceTo(&buf, 0);
    try std.testing.expect(std.mem.indexOf(u8, out, "1.0.0") != null);
}

test "configPrint renders all fields" {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const config = @import("../app/config.zig").Config{
        .repo = "~/.dotfiles",
        .hostname = "nixos",
        .keep = 10,
        .update = false,
        .diff = true,
    };
    try configPrint(&writer, config);
    try std.testing.expect(std.mem.indexOf(u8, &buf, "repo") != null);
    try std.testing.expect(std.mem.indexOf(u8, &buf, "hostname") != null);
    try std.testing.expect(std.mem.indexOf(u8, &buf, "keep") != null);
    try std.testing.expect(std.mem.indexOf(u8, &buf, "update") != null);
    try std.testing.expect(std.mem.indexOf(u8, &buf, "diff") != null);
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
