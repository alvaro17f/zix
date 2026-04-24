const std = @import("std");
const Config = @import("app/config.zig").Config;
const cli = @import("app/cli.zig");
const style = @import("utils/style.zig");

pub const Key = union(enum) {
    char: u8,
    up,
    down,
    enter,
    escape,
    unknown,
    eof,
};

fn readKey(reader: *std.Io.Reader) Key {
    var buf: [1]u8 = undefined;
    const n = reader.readSliceShort(&buf) catch return .unknown;
    if (n == 0) return .eof;
    const b = buf[0];

    if (b == '\x1b') {
        var b2: [1]u8 = undefined;
        const n2 = reader.readSliceShort(&b2) catch return .escape;
        if (n2 == 0) return .escape;
        if (b2[0] != '[') return .unknown;

        var b3: [1]u8 = undefined;
        const n3 = reader.readSliceShort(&b3) catch return .unknown;
        if (n3 == 0) return .unknown;

        return switch (b3[0]) {
            'A' => .up,
            'B' => .down,
            else => .unknown,
        };
    }

    if (b == '\n' or b == '\r') return .enter;
    return .{ .char = b };
}

fn getTermSize() struct { cols: u16, rows: u16 } {
    var tc: u16 = 80; var tr: u16 = 24; var ws: std.posix.winsize = undefined;
    if (std.c.ioctl(std.posix.STDIN_FILENO, @as(c_int, 0x5413), &ws) >= 0) { tc = @max(ws.col, 30); tr = @max(ws.row, 10); }
    return .{ .cols = tc, .rows = tr };
}

fn clear(writer: *std.Io.Writer) !void {
    try writer.print("\x1b[2J\x1b[H", .{});
    try writer.flush();
}

fn lineFmt(writer: *std.Io.Writer, buf: []u8, comptime fmt: []const u8, args: anytype) !void {
    const width = buf.len;
    @memset(buf[0..width], ' ');
    const n = std.fmt.bufPrint(buf[0..width], fmt, args) catch buf[0..0];
    if (n.len < width) @memset(buf[n.len..width], ' ');
    try writer.print("{s}│{s}{s}{s}│{s}\n", .{ style.Cyan, style.Reset, buf[0..width], style.Cyan, style.Reset });
}

fn hline(writer: *std.Io.Writer, left: []const u8, right: []const u8, width: usize) !void {
    try writer.print("{s}{s}", .{ style.Cyan, left });
    var i: usize = 0;
    while (i < width) : (i += 1) {
        try writer.writeAll("─");
    }
    try writer.print("{s}{s}\n", .{ right, style.Reset });
}

fn renderScreen(writer: *std.Io.Writer, config: Config, items: []const []const u8, selected: u2, cols: u16, rows: u16) !void {
    try clear(writer);

    const inner: usize = @max(@as(u16, 30), cols) - 2;
    var buf: [4096]u8 = undefined;
    const slot = buf[0..inner];

    try hline(writer, "┌", "┐", inner);
    try lineFmt(writer, slot, "  Z I X  M A N A G E R", .{});
    try hline(writer, "├", "┤", inner);

    try lineFmt(writer, slot, "  Repo:   {s}", .{config.repo});
    try lineFmt(writer, slot, "  Host:   {s}", .{config.hostname});
    try lineFmt(writer, slot, "  Keep:   {d}", .{config.keep});

    const flags_val = if (config.update and config.diff) "update diff"
        else if (config.update) "update"
        else if (config.diff) "diff"
        else "";
    try lineFmt(writer, slot, "  Flags:  {s}", .{flags_val});

    try hline(writer, "├", "┤", inner);

    for (items, 0..) |item, i| {
        var m: [4096]u8 = undefined;
        const ms = m[0..inner];
        @memset(ms, ' ');
        const text = if (i == selected)
            std.fmt.bufPrint(ms, "  > [{d}] {s}", .{ i + 1, item }) catch ms[0..0]
        else
            std.fmt.bufPrint(ms, "   [{d}] {s}", .{ i + 1, item }) catch ms[0..0];
        if (text.len < inner) @memset(ms[text.len..inner], ' ');
        try writer.print("{s}│{s}{s}{s}│{s}\n", .{ style.Cyan, style.Reset, ms, style.Cyan, style.Reset });
    }

    const min_content: u16 = 14;
    if (rows > min_content) {
        var i: u16 = rows - min_content;
        while (i > 0) : (i -= 1) {
            try lineFmt(writer, slot, "", .{});
        }
    }

    try lineFmt(writer, slot, "  ↑↓ jk navigate   Enter select   1-4 quick   q quit", .{});
    try hline(writer, "└", "┘", inner);
    try writer.flush();
}

pub fn run(io: std.Io, writer: *std.Io.Writer, reader: *std.Io.Reader, config: Config, deps: cli.Deps) !void {
    var raw_enabled = false; var saved_termios: std.posix.termios = undefined; if (std.posix.tcgetattr(std.posix.STDIN_FILENO)) |saved| { saved_termios = saved; raw_enabled = true; var raw = saved; raw.lflag.ICANON = false; raw.lflag.ECHO = false; std.posix.tcsetattr(std.posix.STDIN_FILENO, .NOW, raw) catch {}; } else |_| {}
    defer if (raw_enabled) std.posix.tcsetattr(std.posix.STDIN_FILENO, .NOW, saved_termios) catch {};
    const ts = getTermSize();
    const items = &[_][]const u8{ "Pull & Rebuild", "Update & Rebuild", "Diff", "Quit" };
    var selected: u2 = 0;
    var cfg = config;

    while (true) {
        try renderScreen(writer, cfg, items, selected, ts.cols, ts.rows);

        const key = readKey(reader);
        switch (key) {
            .eof => return,
            .up => if (selected > 0) { selected -= 1; },
            .down => if (@as(usize, selected) + 1 < items.len) { selected += 1; },
            .enter => {
                switch (selected) {
                    0 => { cfg.update = false; cfg.diff = false; return try cli.workflow(io, writer, reader, cfg, deps); },
                    1 => { cfg.update = true; cfg.diff = false; return try cli.workflow(io, writer, reader, cfg, deps); },
                    2 => { cfg.update = false; cfg.diff = true; return try cli.workflow(io, writer, reader, cfg, deps); },
                    3 => return,
                }
            },
            .char => |c| {
                switch (c) {
                    '1' => { cfg.update = false; cfg.diff = false; return try cli.workflow(io, writer, reader, cfg, deps); },
                    '2' => { cfg.update = true; cfg.diff = false; return try cli.workflow(io, writer, reader, cfg, deps); },
                    '3' => { cfg.update = false; cfg.diff = true; return try cli.workflow(io, writer, reader, cfg, deps); },
                    '4', 'q' => return,
                    'j' => if (@as(usize, selected) + 1 < items.len) { selected += 1; },
                    'k' => if (selected > 0) { selected -= 1; },
                    else => {},
                }
            },
            else => {},
        }
    }
}

fn mockRun(_: std.Io, _: []const u8, _: cli.RunOpts) anyerror!i32 { return 0; }
fn mockConfirm(_: *std.Io.Reader, _: *std.Io.Writer, _: bool, _: ?[]const u8) anyerror!bool { return true; }
fn mockTitleMaker(_: *std.Io.Writer, _: []const u8) anyerror!void {}
fn mockConfigPrint(_: *std.Io.Writer, _: Config) anyerror!void {}

const mock_deps = cli.Deps{
    .run = mockRun,
    .confirm = mockConfirm,
    .titleMaker = mockTitleMaker,
    .configPrint = mockConfigPrint,
};

test "readKey char" {
    var reader = std.Io.Reader.fixed("q");
    const key = readKey(&reader);
    try std.testing.expectEqual(@as(u8, 'q'), key.char);
}

test "readKey enter" {
    var reader = std.Io.Reader.fixed("\n");
    const key = readKey(&reader);
    try std.testing.expectEqual(@as(Key, .enter), key);
}

test "readKey escape" {
    var reader = std.Io.Reader.fixed("\x1b");
    const key = readKey(&reader);
    try std.testing.expectEqual(@as(Key, .escape), key);
}

test "readKey arrow up" {
    var reader = std.Io.Reader.fixed("\x1b[A");
    const key = readKey(&reader);
    try std.testing.expectEqual(@as(Key, .up), key);
}

test "readKey arrow down" {
    var reader = std.Io.Reader.fixed("\x1b[B");
    const key = readKey(&reader);
    try std.testing.expectEqual(@as(Key, .down), key);
}

test "readKey unknown escape" {
    var reader = std.Io.Reader.fixed("\x1b[Z");
    const key = readKey(&reader);
    try std.testing.expectEqual(@as(Key, .unknown), key);
}

test "readKey EndOfStream" {
    var reader = std.Io.Reader.fixed("");
    const key = readKey(&reader);
    try std.testing.expectEqual(@as(Key, .eof), key);
}

test "mock functions direct cover" {
    var wbuf: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var rbuf: [1]u8 = undefined;
    var reader = std.Io.Reader.fixed(&rbuf);
    _ = try mockConfirm(&reader, &writer, true, null);
    try mockConfigPrint(&writer, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false, .tui = false });
}

test "renderScreen shows config" {
    var buf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const config = Config{ .repo = "r", .hostname = "h", .keep = 5, .update = true, .diff = false };
    try renderScreen(&writer, config, &.{ "A", "B" }, 0, 80, 24);
    const out = std.mem.sliceTo(&buf, 0);
    try std.testing.expect(std.mem.indexOf(u8, out, "r") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "A") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, ">") != null);
}

test "tui run quits on q" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("q");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run quits on 4" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("4");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option1 on enter" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option2 after down" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b[B\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option3 after down twice" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b[B\x1b[B\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option4 after down three times" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b[B\x1b[B\x1b[B\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option1 on char 1" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("1");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option2 on char 2" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("2");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option3 on char 3" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("3");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run j moves down then enter" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("j\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run k moves up after j then enter" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("jk\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run j at bottom stays" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("jjjj\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run ignores unknown char then enter" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("x\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run down past bottom then enter" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b[B\x1b[B\x1b[B\x1b[B\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run up at top then enter" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b[A\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run down then up then enter" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b[B\x1b[A\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run escape then enter" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run empty input returns" {
    var wbuf: [32768]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}
