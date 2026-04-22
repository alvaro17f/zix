const std = @import("std");
const Config = @import("app/config.zig").Config;
const cli = @import("app/cli.zig");

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

fn clear(writer: *std.Io.Writer) !void {
    try writer.print("\x1b[2J\x1b[H", .{});
    try writer.flush();
}

fn renderScreen(writer: *std.Io.Writer, config: Config, items: []const []const u8, selected: u2) !void {
    try clear(writer);
    try writer.print("==================================================\n", .{});
    try writer.print("  ZIX Configuration\n", .{});
    try writer.print("==================================================\n", .{});
    try writer.print("  Repo:   {s}\n", .{config.repo});
    try writer.print("  Host:   {s}\n", .{config.hostname});
    try writer.print("  Keep:   {d}\n", .{config.keep});
    try writer.print("  Update: {}\n", .{config.update});
    try writer.print("  Diff:   {}\n", .{config.diff});
    try writer.print("==================================================\n\n", .{});

    for (items, 0..) |item, i| {
        const cursor = if (i == selected) "> " else "  ";
        try writer.print("{s}[{d}] {s}\n", .{ cursor, i + 1, item });
    }
    try writer.print("\nUse arrow keys or numbers. Enter to select.\n", .{});
    try writer.flush();
}

pub fn run(io: std.Io, writer: *std.Io.Writer, reader: *std.Io.Reader, config: Config, deps: cli.Deps) !void {
    const items = &[_][]const u8{ "Pull & Rebuild", "Update & Rebuild", "Diff", "Quit" };
    var selected: u2 = 0;
    var cfg = config;

    while (true) {
        try renderScreen(writer, cfg, items, selected);

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
    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const config = Config{ .repo = "r", .hostname = "h", .keep = 5, .update = true, .diff = false };
    try renderScreen(&writer, config, &.{ "A", "B" }, 0);
    const out = std.mem.sliceTo(&buf, 0);
    try std.testing.expect(std.mem.indexOf(u8, out, "r") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "A") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, ">") != null);
}

test "tui run quits on q" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("q");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run quits on 4" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("4");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option1 on enter" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option2 after down" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b[B\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option3 after down twice" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b[B\x1b[B\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option4 after down three times" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b[B\x1b[B\x1b[B\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option1 on char 1" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("1");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option2 on char 2" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("2");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run option3 on char 3" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("3");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run ignores unknown char then enter" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("x\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run down past bottom then enter" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b[B\x1b[B\x1b[B\x1b[B\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run up at top then enter" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b[A\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run down then up then enter" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b[B\x1b[A\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run escape then enter" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("\x1b\n");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}

test "tui run empty input returns" {
    var wbuf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&wbuf);
    var reader = std.Io.Reader.fixed("");
    try run(std.testing.io, &writer, &reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, mock_deps);
}
