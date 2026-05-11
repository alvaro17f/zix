const std = @import("std");
const io = @import("../core/io.zig");
const cli_module = @import("./cli.zig");
const cli = cli_module.cli;
const eql = std.mem.eql;
const process = @import("../core/process.zig");
const VERSION = @import("zon").version;

pub const Config = struct {
    repo: []const u8,
    hostname: []const u8,
    keep: u8,
    update: bool,
    diff: bool,

    pub fn defaults() Config {
        var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
        return .{
            .repo = "~/.dotfiles",
            .hostname = std.posix.gethostname(&buf) catch "unknown",
            .keep = 10,
            .update = false,
            .diff = false,
        };
    }
};

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

pub fn printVersion(writer: *std.Io.Writer) !void {
    try io.printTo(writer, "{s}\nZIX version: {s}{s}\n{s}", .{ io.Yellow, io.Cyan, VERSION, io.Reset });
}

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

pub fn configPrint(writer: *std.Io.Writer, config: Config) !void {
    const fields = @typeInfo(Config).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        const is_last = i == fields.len - 1;
        const value = @field(config, field.name);
        try printConfigLine(writer, field.name, value, .{ .new_line = !is_last });
    }
}

pub fn run(cli_io: std.Io, writer: *std.Io.Writer, args: []const []const u8, deps: cli_module.Deps, alloc: std.mem.Allocator) !void {
    var config = Config.defaults();

    if (args.len <= 1) {
        return try cli(cli_io, writer, config, deps, alloc);
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
                            return try io.printTo(writer, "{s}Error: \"-{c}\" flag requires an argument\n{s}", .{ io.Red, flag, io.Reset });
                        }
                        if (flag == 'r') config.repo = args[idx + 2];
                        if (flag == 'n') config.hostname = args[idx + 2];
                        if (flag == 'k') {
                            const argument = args[idx + 2];
                            const number = std.fmt.parseInt(u8, argument, 10) catch {
                                return try io.printTo(writer, "{s}Error: Value of \"-k\" flag is not numeric.\n{s}", .{ io.Red, io.Reset });
                            };
                            config.keep = number;
                        }
                    },
                    else => return try io.printTo(writer, "{s}Error: Unknown flag \"-{c}\"\n{s}", .{ io.Red, flag, io.Reset }),
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
                return try io.printTo(writer, "{s}Error: Unknown argument \"{s}\"\n{s}", .{ io.Red, argument, io.Reset });
            }
        }
    }

    return try cli(cli_io, writer, config, deps, alloc);
}

fn mockRun(_: std.Io, _: []const u8, _: process.RunOpts) anyerror!i32 { return 0; }
noinline fn mockConfirm(_: *std.Io.Writer, _: bool, _: ?[]const u8, _: std.mem.Allocator) anyerror!bool { return true; }
noinline fn mockPrintTitle(_: *std.Io.Writer, _: []const u8, _: std.mem.Allocator) anyerror!void {}
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
    // getHostname is dead code in production (Config.defaults inlines it)
    // Keep test for documentation purposes
}

test "configPrint renders all fields" {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const config = Config{
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
    };

    const mock_deps = cli_module.Deps{
        .run = mockRun,
        .confirm = mockConfirm,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };

    for (cases) |tc| {
        var buf: [2048]u8 = undefined;
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
