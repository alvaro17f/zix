const std = @import("std");
const io = @import("../core/io.zig");
const cmd = @import("../core/commands.zig");
const process = @import("../core/process.zig");
const Config = @import("config.zig").Config;

pub const Deps = struct {
    run: *const fn (std.Io, []const u8, process.RunOpts) anyerror!i32,
    confirm: *const fn (*std.Io.Writer, bool, ?[]const u8, std.mem.Allocator) anyerror!bool,
    printTitle: *const fn (*std.Io.Writer, []const u8, std.mem.Allocator) anyerror!void,
    configPrint: *const fn (*std.Io.Writer, Config) anyerror!void,
};

pub fn cli(cli_io: std.Io, writer: *std.Io.Writer, config: Config, deps: Deps, allocator: std.mem.Allocator) !void {
    // Arena for transient command strings freed on scope exit.
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    try deps.printTitle(writer, "ZIX Configuration", allocator);
    try deps.configPrint(writer, config);

    if (try deps.confirm(writer, true, null, allocator)) {
        try pullRepo(cli_io, writer, arena_allocator, config.repo, deps, allocator);

        if (config.update) {
            try deps.printTitle(writer, "Nix Update", allocator);
            _ = try deps.run(cli_io, try cmd.nixUpdate(arena_allocator, config.repo), .{});
        }

        try stageGitChanges(cli_io, writer, arena_allocator, config.repo, deps, allocator);

        try deps.printTitle(writer, "Nixos Rebuild", allocator);
        _ = try deps.run(cli_io, try cmd.nixRebuild(arena_allocator, config.repo, config.hostname), .{});
        _ = try deps.run(cli_io, try cmd.nixKeep(arena_allocator, config.keep), .{});

        if (config.diff) {
            try deps.printTitle(writer, "Nix Diff", allocator);
            _ = try deps.run(cli_io, cmd.nixDiff, .{});
        }
    }
}

fn pullRepo(cli_io: std.Io, writer: *std.Io.Writer, arena_allocator: std.mem.Allocator, repo: []const u8, deps: Deps, allocator: std.mem.Allocator) !void {
    try deps.printTitle(writer, "Git Pull", allocator);
    const status = try deps.run(cli_io, try cmd.gitPull(arena_allocator, repo), .{});
    if (status != 0) {
        try io.printTo(writer, "{s}Failed to pull changes{s}\n", .{ io.Red, io.Reset });
        return error.GitPullFailed;
    }
}

fn stageGitChanges(cli_io: std.Io, writer: *std.Io.Writer, arena_allocator: std.mem.Allocator, repo: []const u8, deps: Deps, allocator: std.mem.Allocator) !void {
    // diff --exit-code returns 1 when there are unstaged changes.
    if (try deps.run(cli_io, try cmd.gitDiff(arena_allocator, repo), .{ .output = false }) != 1) return;

    try deps.printTitle(writer, "Git Changes", allocator);
    _ = try deps.run(cli_io, try cmd.gitStatus(arena_allocator, repo), .{});

    if (try deps.confirm(writer, true, "Do you want to add these changes to the stage?", allocator)) {
        _ = deps.run(cli_io, try cmd.gitAdd(arena_allocator, repo), .{}) catch |err| {
            try io.printTo(writer, "{s}Failed to add changes to the stage: {}{s}\n", .{ io.Red, err, io.Reset });
            return;
        };
        try io.printTo(writer, "{s}Changes added to git stage successfully{s}\n", .{ io.Green, io.Reset });
    } else {
        try io.printTo(writer, "{s}Changes not added to stage{s}\n", .{ io.Red, io.Reset });
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
fn mockConfirmCounting(_: *std.Io.Writer, _: bool, _: ?[]const u8, _: std.mem.Allocator) anyerror!bool {
    confirm_call_count += 1;
    return confirm_call_count != 2;
}
fn mockConfirmTrue(_: *std.Io.Writer, _: bool, _: ?[]const u8, _: std.mem.Allocator) anyerror!bool {
    return true;
}
fn mockConfirmFalse(_: *std.Io.Writer, _: bool, _: ?[]const u8, _: std.mem.Allocator) anyerror!bool {
    return false;
}
fn mockPrintTitle(_: *std.Io.Writer, _: []const u8, _: std.mem.Allocator) anyerror!void {}
fn mockConfigPrint(_: *std.Io.Writer, _: Config) anyerror!void {}

// --- Tests ---

test "cli branches" {
    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const cli_io = std.testing.io;

    const deps = Deps{
        .run = mockRun,
        .confirm = mockConfirmTrue,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };

    // confirm false => early return
    const no_deps = Deps{
        .run = mockRun,
        .confirm = mockConfirmFalse,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };
    try cli(cli_io, &writer, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, no_deps, std.testing.allocator);

    // git pull fails
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
    try std.testing.expectError(error.GitPullFailed, cli(cli_io, &writer, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, fail_deps, std.testing.allocator));

    // update + diff + git changes + add
    try cli(cli_io, &writer, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = true, .diff = true }, deps, std.testing.allocator);

    // no git changes (diff returns 0)
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
    try cli(cli_io, &writer, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, no_changes_deps, std.testing.allocator);
}

test "cli git add failure" {
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

    try cli(cli_io, &writer, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = true }, add_fail_deps, std.testing.allocator);
    const out = std.mem.sliceTo(&buf, 0);
    try std.testing.expect(std.mem.indexOf(u8, out, "Failed to add changes") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "successfully") == null);
}

test "cli decline add changes" {
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
    try cli(cli_io, &writer, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = true }, decline_deps, std.testing.allocator);
    const out = std.mem.sliceTo(&buf, 0);
    try std.testing.expect(std.mem.indexOf(u8, out, "not added") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "successfully") == null);
}
