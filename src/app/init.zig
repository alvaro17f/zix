const std = @import("std");
const io = @import("../core/io.zig");
const ui = @import("../core/ui.zig");
const cli_module = @import("./cli.zig");
const buildCommands = cli_module.buildCommands;
const execute = cli_module.execute;
const equal = std.mem.eql;
const process = @import("../core/process.zig");
const Config = @import("config.zig").Config;
const StaticAllocator = @import("../core/static_allocator.zig");
const VERSION = @import("zon").version;

pub fn run(
    cli_io: std.Io,
    writer: *std.Io.Writer,
    args: []const []const u8,
    deps: cli_module.Deps,
    static_allocator: *StaticAllocator,
) !void {
    // Assert preconditions: args must not be empty.
    std.debug.assert(args.len >= 1);

    const allocator = static_allocator.allocator();

    // Hostname buffer must outlive config to avoid dangling pointer.
    var hostname_buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
    var config = Config.defaults(&hostname_buf);

    if (args.len <= 1) {
        // Phase 1: build commands (allocation allowed).
        const commands = try buildCommands(config, allocator);
        // Transition: no more allocation after this point.
        static_allocator.transition_from_init_to_static();
        // Phase 2: execute (zero allocation).
        return try execute(cli_io, writer, config, commands, deps);
    }

    // Parse flags: each '-' introduces one or more single-char flags.
    var arg_index: u32 = 1;
    while (arg_index < args.len) : (arg_index += 1) {
        const arg = args[arg_index];
        // Each arg must be non-empty.
        std.debug.assert(arg.len > 0);
        if (arg[0] == '-') {
            for (arg[1..]) |flag| {
                switch (flag) {
                    'h' => {
                        return try ui.printHelp(writer);
                    },
                    'v' => {
                        return try ui.printVersion(writer, VERSION);
                    },
                    'd' => config.diff = true,
                    'u' => config.update = true,
                    'r', 'n', 'k' => {
                        // These flags consume the next argument as their value.
                        arg_index += 1;
                        if (arg_index >= args.len) {
                            return try io.printTo(
                                writer,
                                "{s}Error: \"-{c}\" flag requires an argument\n{s}",
                                .{ io.Red, flag, io.Reset },
                            );
                        }
                        if (flag == 'r') config.repo = args[arg_index];
                        if (flag == 'n') config.hostname = args[arg_index];
                        if (flag == 'k') {
                            const number = std.fmt.parseInt(u8, args[arg_index], 10) catch {
                                return try io.printTo(
                                    writer,
                                    "{s}Error: Value of \"-k\" flag is not numeric.\n{s}",
                                    .{ io.Red, io.Reset },
                                );
                            };
                            config.keep = number;
                        }
                    },
                    else => return try io.printTo(
                        writer,
                        "{s}Error: Unknown flag \"-{c}\"\n{s}",
                        .{ io.Red, flag, io.Reset },
                    ),
                }
            }
        } else {
            if (equal(u8, arg, "help")) {
                return try ui.printHelp(writer);
            }
            if (equal(u8, arg, "version")) {
                return try ui.printVersion(writer, VERSION);
            }
            return try io.printTo(
                writer,
                "{s}Error: Unknown argument \"{s}\"\n{s}",
                .{ io.Red, arg, io.Reset },
            );
        }
    }

    // Validate after all flags are parsed so partial configs get caught.
    if (config.validate()) |error_message| {
        return try io.printTo(writer, "{s}Error: {s}{s}\n", .{ io.Red, error_message, io.Reset });
    }

    // Phase 1: build commands (allocation allowed).
    const commands = try buildCommands(config, allocator);
    // Transition: no more allocation after this point.
    static_allocator.transition_from_init_to_static();
    // Phase 2: execute (zero allocation).
    return try execute(cli_io, writer, config, commands, deps);
}

// --- Test Mocks ---

fn mockRun(_: std.Io, _: []const u8, _: process.RunOpts) anyerror!i32 {
    return 0;
}
noinline fn mockConfirm(
    _: *std.Io.Writer,
    _: bool,
    _: ?[]const u8,
) anyerror!bool {
    return true;
}
noinline fn mockPrintTitle(_: *std.Io.Writer, _: []const u8) anyerror!void {}
noinline fn mockConfigPrint(_: *std.Io.Writer, _: Config) anyerror!void {}

// --- Tests ---

test "run flag branches" {
    const test_io = std.testing.io;

    var memory: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&memory);

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
        // Reset FBA for each test case to get clean memory.
        fba.reset();
        var static_alloc = StaticAllocator.init(fba.allocator());
        var buf = [_]u8{0} ** 2048;
        var writer = std.Io.Writer.fixed(&buf);
        run(test_io, &writer, tc.args, mock_deps, &static_alloc) catch continue;
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

    var memory: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&memory);
    var static_allocator = StaticAllocator.init(fba.allocator());

    const mock_deps = cli_module.Deps{
        .run = mockRun,
        .confirm = mockConfirm,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };

    try run(test_io, &writer, &.{"zix"}, mock_deps, &static_allocator);
}

test "run rejects invalid config via flags" {
    const test_io = std.testing.io;
    var buf: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    var memory: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&memory);
    var static_allocator = StaticAllocator.init(fba.allocator());

    const mock_deps = cli_module.Deps{
        .run = mockRun,
        .confirm = mockConfirm,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };

    // -k 0 triggers validate error.
    try run(test_io, &writer, &.{ "zix", "-k", "0" }, mock_deps, &static_allocator);
    const out = std.mem.sliceTo(&buf, 0);
    try std.testing.expect(std.mem.indexOf(u8, out, "Error") != null);
}
