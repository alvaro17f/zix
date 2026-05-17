const std = @import("std");
const io = @import("../core/io.zig");
const cmd = @import("../core/commands.zig");
const process = @import("../core/process.zig");
const Config = @import("config.zig").Config;

pub const Deps = struct {
    run: *const fn (std.Io, []const u8, process.RunOpts) anyerror!i32,
    confirm: *const fn (*std.Io.Writer, bool, ?[]const u8) anyerror!bool,
    printTitle: *const fn (*std.Io.Writer, []const u8) anyerror!void,
    configPrint: *const fn (*std.Io.Writer, Config) anyerror!void,
};

pub fn cli(
    cli_io: std.Io,
    writer: *std.Io.Writer,
    config: Config,
    deps: Deps,
    allocator: std.mem.Allocator,
) !void {
    // Assert preconditions: repo and hostname must be valid strings.
    std.debug.assert(config.repo.len > 0);
    std.debug.assert(config.hostname.len > 0);
    std.debug.assert(config.keep > 0);

    try deps.printTitle(writer, "ZIX Configuration");
    try deps.configPrint(writer, config);

    if (try deps.confirm(writer, true, null)) {
        try pullRepo(cli_io, writer, config.repo, deps, allocator);

        if (config.update) {
            try deps.printTitle(writer, "Nix Update");
            const update_cmd = try cmd.nixUpdate(allocator, config.repo);
            _ = try deps.run(cli_io, update_cmd, .{});
        }

        try stageGitChanges(cli_io, writer, config.repo, deps, allocator);

        try deps.printTitle(writer, "Nixos Rebuild");
        const rebuild_cmd = try cmd.nixRebuild(
            allocator,
            config.repo,
            config.hostname,
        );
        _ = try deps.run(cli_io, rebuild_cmd, .{});
        const keep_cmd = try cmd.nixKeep(allocator, config.keep);
        _ = try deps.run(cli_io, keep_cmd, .{});

        if (config.diff) {
            try deps.printTitle(writer, "Nix Diff");
            _ = try deps.run(cli_io, cmd.nixDiff, .{});
        }
    }
}

fn pullRepo(
    cli_io: std.Io,
    writer: *std.Io.Writer,
    repo: []const u8,
    deps: Deps,
    allocator: std.mem.Allocator,
) !void {
    // Assert preconditions: repo must be a valid path.
    std.debug.assert(repo.len > 0);

    try deps.printTitle(writer, "Git Pull");
    const pull_cmd = try cmd.gitPull(allocator, repo);
    const status = try deps.run(cli_io, pull_cmd, .{});
    if (status != 0) {
        try io.printTo(writer, "{s}Failed to pull changes{s}\n", .{ io.Red, io.Reset });
        return error.GitPullFailed;
    }
}

fn stageGitChanges(
    cli_io: std.Io,
    writer: *std.Io.Writer,
    repo: []const u8,
    deps: Deps,
    allocator: std.mem.Allocator,
) !void {
    // Assert preconditions: repo must be a valid path.
    std.debug.assert(repo.len > 0);

    // diff --exit-code returns 1 when there are unstaged changes.
    const diff_cmd = try cmd.gitDiff(allocator, repo);
    const has_changes = try deps.run(cli_io, diff_cmd, .{ .output = false });
    if (has_changes != 1) return;

    try deps.printTitle(writer, "Git Changes");
    const status_cmd = try cmd.gitStatus(allocator, repo);
    _ = try deps.run(cli_io, status_cmd, .{});

    if (try deps.confirm(
        writer,
        true,
        "Do you want to add these changes to the stage?",
    )) {
        const add_cmd = try cmd.gitAdd(allocator, repo);
        _ = deps.run(cli_io, add_cmd, .{}) catch |err| {
            try io.printTo(
                writer,
                "{s}Failed to add changes to the stage: {}{s}\n",
                .{ io.Red, err, io.Reset },
            );
            return;
        };
        try io.printTo(
            writer,
            "{s}Changes added to git stage successfully{s}\n",
            .{ io.Green, io.Reset },
        );
    } else {
        try io.printTo(
            writer,
            "{s}Changes not added to stage{s}\n",
            .{ io.Red, io.Reset },
        );
    }
}

// --- Test Mocks ---

fn mockRun(_: std.Io, command: []const u8, _: process.RunOpts) anyerror!i32 {
    if (std.mem.startsWith(u8, command, "git -C")) {
        if (std.mem.indexOf(u8, command, "diff --exit-code") != null) return 1;
    }
    return 0;
}
var confirm_call_count: u32 = 0;
fn mockConfirmCounting(
    _: *std.Io.Writer,
    _: bool,
    _: ?[]const u8,
) anyerror!bool {
    confirm_call_count += 1;
    return confirm_call_count != 2;
}
fn mockConfirmTrue(
    _: *std.Io.Writer,
    _: bool,
    _: ?[]const u8,
) anyerror!bool {
    return true;
}
fn mockConfirmFalse(
    _: *std.Io.Writer,
    _: bool,
    _: ?[]const u8,
) anyerror!bool {
    return false;
}
fn mockPrintTitle(_: *std.Io.Writer, _: []const u8) anyerror!void {}
fn mockConfigPrint(_: *std.Io.Writer, _: Config) anyerror!void {}

// --- Tests ---

fn testConfig(update: bool, diff: bool) Config {
    return Config{
        .repo = "r",
        .hostname = "h",
        .keep = 1,
        .update = update,
        .diff = diff,
    };
}

test "cli branches" {
    var memory: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&memory);
    const allocator = fba.allocator();

    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const cli_io = std.testing.io;

    const deps = Deps{
        .run = mockRun,
        .confirm = mockConfirmTrue,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };

    // confirm false => early return.
    const no_deps = Deps{
        .run = mockRun,
        .confirm = mockConfirmFalse,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };
    try cli(cli_io, &writer, testConfig(false, false), no_deps, allocator);

    // git pull fails.
    const fail_deps = Deps{
        .run = struct {
            fn f(_: std.Io, _: []const u8, _: process.RunOpts) anyerror!i32 {
                return 1;
            }
        }.f,
        .confirm = mockConfirmTrue,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };
    try std.testing.expectError(
        error.GitPullFailed,
        cli(cli_io, &writer, testConfig(false, false), fail_deps, allocator),
    );

    // update + diff + git changes + add.
    try cli(cli_io, &writer, testConfig(true, true), deps, allocator);

    // no git changes (diff returns 0).
    const no_changes_deps = Deps{
        .run = struct {
            fn f(_: std.Io, _: []const u8, _: process.RunOpts) anyerror!i32 {
                return 0;
            }
        }.f,
        .confirm = mockConfirmTrue,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };
    try cli(cli_io, &writer, testConfig(false, false), no_changes_deps, allocator);
}

test "cli git add failure" {
    var memory: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&memory);
    const allocator = fba.allocator();

    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const cli_io = std.testing.io;

    const add_fail_deps = Deps{
        .run = struct {
            fn f(_: std.Io, c: []const u8, _: process.RunOpts) anyerror!i32 {
                if (std.mem.indexOf(u8, c, "add .") != null) return error.MockError;
                if (std.mem.indexOf(u8, c, "diff --exit-code") != null) return 1;
                return 0;
            }
        }.f,
        .confirm = mockConfirmTrue,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };

    try cli(cli_io, &writer, testConfig(false, true), add_fail_deps, allocator);
    const out = std.mem.sliceTo(&buf, 0);
    try std.testing.expect(std.mem.indexOf(u8, out, "Failed to add changes") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "successfully") == null);
}

test "cli decline add changes" {
    var memory: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&memory);
    const allocator = fba.allocator();

    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const cli_io = std.testing.io;

    confirm_call_count = 0;
    const decline_deps = Deps{
        .run = mockRun,
        .confirm = mockConfirmCounting,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };
    try cli(cli_io, &writer, testConfig(false, true), decline_deps, allocator);
    const out = std.mem.sliceTo(&buf, 0);
    try std.testing.expect(std.mem.indexOf(u8, out, "not added") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "successfully") == null);
}
