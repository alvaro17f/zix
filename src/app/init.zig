const std = @import("std");
const allocator = @import("../utils/allocator.zig").allocator;
const fmt = @import("../utils/fmt.zig");
const cli_module = @import("./cli.zig");
const cli = cli_module.cli;
const eql = std.mem.eql;
const style = @import("../utils/style.zig");
const VERSION = @import("zon").version;

pub const Config = struct {
    repo: []const u8,
    hostname: []const u8,
    keep: u8,
    update: bool,
    diff: bool,
};

pub fn printHelp(writer: *std.Io.Writer) !void {
    try fmt.printTo(writer,
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

pub fn printVersion(writer: *std.Io.Writer) !void {
    try fmt.printTo(writer, "{s}\nZIX version: {s}{s}\n{s}", .{ style.Yellow, style.Cyan, VERSION, style.Reset });
}

pub fn getHostname(buffer: *[64]u8) []const u8 {
    return std.posix.gethostname(buffer) catch "unknown";
}

pub fn run(io: std.Io, writer: *std.Io.Writer, reader: *std.Io.Reader, args: []const []const u8, deps: cli_module.Deps) !void {
    var hostname_buffer: [std.posix.HOST_NAME_MAX]u8 = undefined;

    var config = Config{
        .repo = "~/.dotfiles",
        .hostname = getHostname(&hostname_buffer),
        .keep = 10,
        .update = false,
        .diff = false,
    };

    if (args.len <= 1) {
        return try cli(io, writer, reader, config, deps);
    }

    for (args[1..], 0..) |arg, idx| {
        if (arg[0] == '-') {
            for (arg[1..]) |flag| {
                switch (flag) {
                    'h' => {
                        return try printHelp(writer);
                    },
                    'v' => {
                        return try printVersion(writer);
                    },
                    'd' => config.diff = true,
                    'u' => config.update = true,
                    'r', 'n', 'k' => {
                        if (idx + 2 >= args.len) {
                            return try fmt.printTo(writer, "{s}Error: \"-{c}\" flag requires an argument\n{s}", .{ style.Red, flag, style.Reset });
                        }
                        if (flag == 'r') config.repo = args[idx + 2];
                        if (flag == 'n') config.hostname = args[idx + 2];
                        if (flag == 'k') {
                            const argument = args[idx + 2];
                            const number = std.fmt.parseInt(u8, argument, 10) catch {
                                return try fmt.printTo(writer, "{s}Error: Value of \"-k\" flag is not numeric.\n{s}", .{ style.Red, style.Reset });
                            };
                            config.keep = number;
                        }
                    },
                    else => return try fmt.printTo(writer, "{s}Error: Unknown flag \"-{c}\"\n{s}", .{ style.Red, flag, style.Reset }),
                }
            }
        } else if (idx == 0) {
            for (args[1..]) |argument| {
                if (eql(u8, argument, "help")) {
                    return try printHelp(writer);
                }
                if (eql(u8, argument, "version")) {
                    return try printVersion(writer);
                }
                return try fmt.printTo(writer, "{s}Error: Unknown argument \"{s}\"\n{s}", .{ style.Red, argument, style.Reset });
            }
        }
    }

    return try cli(io, writer, reader, config, deps);
}

fn mockRun(_: std.Io, _: []const u8, _: cli_module.RunOpts) anyerror!i32 { var x: i32 = 0; x += 1; return x - 1; }
noinline fn mockConfirm(_: *std.Io.Reader, _: *std.Io.Writer, _: bool, _: ?[]const u8) anyerror!bool { return true; }
noinline fn mockTitleMaker(_: *std.Io.Writer, _: []const u8) anyerror!void {}
noinline fn mockConfigPrint(_: *std.Io.Writer, _: Config) anyerror!void {}

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
    try printVersion(&writer);
    const out = std.mem.sliceTo(&buf, 0);
    try std.testing.expect(std.mem.indexOf(u8, out, VERSION) != null);
}

test "getHostname non-empty" {
    var buf: [64]u8 = undefined;
    const h = getHostname(&buf);
    try std.testing.expect(h.len > 0);
}

test "run flag branches" {
    const io = std.testing.io;
    const TestCase = struct {
        args: []const []const u8,
        expect_contains: ?[]const u8 = null,
    };
    const cases = &[_]TestCase{
        .{ .args = &.{ "zix", "-h" }, .expect_contains = "ZIX" },
        .{ .args = &.{ "zix", "-v" }, .expect_contains = VERSION },
        .{ .args = &.{ "zix", "help" }, .expect_contains = "ZIX" },
        .{ .args = &.{ "zix", "version" }, .expect_contains = VERSION },
        .{ .args = &.{ "zix", "unknown" }, .expect_contains = "Unknown argument" },
        .{ .args = &.{ "zix", "-r" }, .expect_contains = "requires an argument" },
        .{ .args = &.{ "zix", "-n" }, .expect_contains = "requires an argument" },
        .{ .args = &.{ "zix", "-k", "abc" }, .expect_contains = "not numeric" },
        .{ .args = &.{ "zix", "-k", "5", "-h" }, .expect_contains = "ZIX" },
        .{ .args = &.{ "zix", "-x" }, .expect_contains = "Unknown flag" },
        .{ .args = &.{ "zix", "-d" }, .expect_contains = null },
        .{ .args = &.{ "zix", "-u" }, .expect_contains = null },
    };

    const mock_deps = cli_module.Deps{
        .run = mockRun,
        .confirm = mockConfirm,
        .titleMaker = mockTitleMaker,
        .configPrint = mockConfigPrint,
    };

    for (cases) |tc| {
        var buf: [2048]u8 = undefined;
        var writer = std.Io.Writer.fixed(&buf);
        run(io, &writer, std.Io.Reader.ending, tc.args, mock_deps) catch continue;
        if (tc.expect_contains) |needle| {
            const out = std.mem.sliceTo(&buf, 0);
            try std.testing.expect(std.mem.indexOf(u8, out, needle) != null);
        }
    }
}

test "run reaches cli" {
    const io = std.testing.io;
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const mock_deps = cli_module.Deps{
        .run = mockRun,
        .confirm = mockConfirm,
        .titleMaker = mockTitleMaker,
        .configPrint = mockConfigPrint,
    };

    try run(io, &writer, std.Io.Reader.ending, &.{"zix"}, mock_deps);
}
