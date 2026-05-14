const std = @import("std");
const io = @import("../core/io.zig");
const ui = @import("../core/ui.zig");
const cli_module = @import("./cli.zig");
const cli = cli_module.cli;
const eql = std.mem.eql;
const process = @import("../core/process.zig");
const config_mod = @import("config.zig");
pub const Config = config_mod.Config;
const VERSION = @import("zon").version;

pub fn run(cli_io: std.Io, writer: *std.Io.Writer, args: []const []const u8, deps: cli_module.Deps, alloc: std.mem.Allocator) !void {
    var hostname_buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
    var config = Config.defaults(&hostname_buf);

    if (args.len <= 1) {
        return try cli(cli_io, writer, config, deps, alloc);
    }

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (arg[0] == '-') {
            for (arg[1..]) |flag| {
                switch (flag) {
                    'h' => { return try ui.printHelp(writer); },
                    'v' => { return try ui.printVersion(writer, VERSION); },
                    'd' => config.diff = true,
                    'u' => config.update = true,
                    'r', 'n', 'k' => {
                        i += 1;
                        if (i >= args.len) {
                            return try io.printTo(writer, "{s}Error: \"-{c}\" flag requires an argument\n{s}", .{ io.Red, flag, io.Reset });
                        }
                        if (flag == 'r') config.repo = args[i];
                        if (flag == 'n') config.hostname = args[i];
                        if (flag == 'k') {
                            const number = std.fmt.parseInt(u8, args[i], 10) catch {
                                return try io.printTo(writer, "{s}Error: Value of \"-k\" flag is not numeric.\n{s}", .{ io.Red, io.Reset });
                            };
                            config.keep = number;
                        }
                    },
                    else => return try io.printTo(writer, "{s}Error: Unknown flag \"-{c}\"\n{s}", .{ io.Red, flag, io.Reset }),
                }
            }
        } else {
            if (eql(u8, arg, "help")) { return try ui.printHelp(writer); }
            if (eql(u8, arg, "version")) { return try ui.printVersion(writer, VERSION); }
            return try io.printTo(writer, "{s}Error: Unknown argument \"{s}\"\n{s}", .{ io.Red, arg, io.Reset });
        }
    }

    if (config.validate()) |err_msg| {
        return try io.printTo(writer, "{s}Error: {s}{s}\n", .{ io.Red, err_msg, io.Reset });
    }

    return try cli(cli_io, writer, config, deps, alloc);
}

fn mockRun(_: std.Io, _: []const u8, _: process.RunOpts) anyerror!i32 { return 0; }
noinline fn mockConfirm(_: *std.Io.Writer, _: bool, _: ?[]const u8, _: std.mem.Allocator) anyerror!bool { return true; }
noinline fn mockPrintTitle(_: *std.Io.Writer, _: []const u8, _: std.mem.Allocator) anyerror!void {}
noinline fn mockConfigPrint(_: *std.Io.Writer, _: Config) anyerror!void {}

test "run flag branches" {
    const test_io = std.testing.io;
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
        .{ .args = &.{ "zix", "-d", "help" }, .expect_contains = "ZIX" },
        .{ .args = &.{ "zix", "-d", "unknown" }, .expect_contains = "Unknown argument" },
    };

    const mock_deps = cli_module.Deps{
        .run = mockRun,
        .confirm = mockConfirm,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };

    for (cases) |tc| {
        var buf = [_]u8{0} ** 2048;
        var writer = std.Io.Writer.fixed(&buf);
        run(test_io, &writer, tc.args, mock_deps, std.testing.allocator) catch continue;
        if (tc.expect_contains) |needle| {
            const out = std.mem.sliceTo(&buf, 0);
            try std.testing.expect(std.mem.indexOf(u8, out, needle) != null);
        }
    }
}

test "run reaches cli" {
    const test_io = std.testing.io;
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const mock_deps = cli_module.Deps{
        .run = mockRun,
        .confirm = mockConfirm,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };

    try run(test_io, &writer, &.{"zix"}, mock_deps, std.testing.allocator);
}

test "run rejects invalid config via flags" {
    const test_io = std.testing.io;
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    const mock_deps = cli_module.Deps{
        .run = mockRun,
        .confirm = mockConfirm,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };

    // -k 0 triggers validate error
    try run(test_io, &writer, &.{ "zix", "-k", "0" }, mock_deps, std.testing.allocator);
    const out = std.mem.sliceTo(&buf, 0);
    try std.testing.expect(std.mem.indexOf(u8, out, "Error") != null);
}
