const std = @import("std");
const fmt = @import("../utils/fmt.zig");
const cmd = @import("../utils/commands.zig");
const tools = @import("../utils/tools.zig");
const Config = @import("init.zig").Config;
const style = @import("../utils/style.zig");

pub const Deps = struct {
    run: *const fn (std.Io, []const u8, tools.RunOpts) anyerror!i32,
    confirm: *const fn (*std.Io.Reader, *std.Io.Writer, bool, ?[]const u8, std.mem.Allocator) anyerror!bool,
    printTitle: *const fn (*std.Io.Writer, []const u8, std.mem.Allocator) anyerror!void,
    configPrint: *const fn (*std.Io.Writer, Config) anyerror!void,
};

pub fn cli(io: std.Io, writer: *std.Io.Writer, reader: *std.Io.Reader, config: Config, deps: Deps, alloc: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const allocator = arena.allocator();

    try deps.printTitle(writer, "ZIX Configuration", alloc);
    try deps.configPrint(writer, config);

    if (try deps.confirm(reader, writer, true, null, alloc)) {
        try pullRepo(io, writer, allocator, config.repo, deps, alloc);

        if (config.update) {
            try deps.printTitle(writer, "Nix Update", alloc);
            _ = try deps.run(io, try cmd.nixUpdate(allocator, config.repo), .{});
        }

        try stageGitChanges(io, writer, reader, allocator, config.repo, deps, alloc);

        try deps.printTitle(writer, "Nixos Rebuild", alloc);
        _ = try deps.run(io, try cmd.nixRebuild(allocator, config.repo, config.hostname), .{});
        _ = try deps.run(io, try cmd.nixKeep(allocator, config.keep), .{});

        if (config.diff) {
            try deps.printTitle(writer, "Nix Diff", alloc);
            _ = try deps.run(io, cmd.nixDiff, .{});
        }
    }
}

fn pullRepo(io: std.Io, writer: *std.Io.Writer, allocator: std.mem.Allocator, repo: []const u8, deps: Deps, alloc: std.mem.Allocator) !void {
    try deps.printTitle(writer, "Git Pull", alloc);
    const status = try deps.run(io, try cmd.gitPull(allocator, repo), .{});
    if (status != 0) {
        try fmt.printTo(writer, "{s}Failed to pull changes{s}\n", .{ style.Red, style.Reset });
        return error.GitPullFailed;
    }
}

fn stageGitChanges(io: std.Io, writer: *std.Io.Writer, reader: *std.Io.Reader, allocator: std.mem.Allocator, repo: []const u8, deps: Deps, alloc: std.mem.Allocator) !void {
    if (try deps.run(io, try cmd.gitDiff(allocator, repo), .{ .output = false }) != 1) return;

    try deps.printTitle(writer, "Git Changes", alloc);
    _ = try deps.run(io, try cmd.gitStatus(allocator, repo), .{});

    if (try deps.confirm(reader, writer, true, "Do you want to add these changes to the stage?", alloc)) {
        _ = deps.run(io, try cmd.gitAdd(allocator, repo), .{}) catch |err| {
            try fmt.printTo(writer, "Failed to add changes to the stage: {}\n", .{err});
        };
        try fmt.printTo(writer, "\n{s}Changes added to git stage successfully{s}\n", .{ style.Green, style.Reset });
    }
}

fn mockRun(_: std.Io, c: []const u8, _: tools.RunOpts) anyerror!i32 {
    if (std.mem.startsWith(u8, c, "git -C")) {
        if (std.mem.indexOf(u8, c, "diff --exit-code") != null) return 1;
    }
    return 0;
}
fn mockConfirmTrue(_: *std.Io.Reader, _: *std.Io.Writer, _: bool, _: ?[]const u8, _: std.mem.Allocator) anyerror!bool { return true; }
fn mockConfirmFalse(_: *std.Io.Reader, _: *std.Io.Writer, _: bool, _: ?[]const u8, _: std.mem.Allocator) anyerror!bool { return false; }
fn mockPrintTitle(_: *std.Io.Writer, _: []const u8, _: std.mem.Allocator) anyerror!void {}
fn mockConfigPrint(_: *std.Io.Writer, _: Config) anyerror!void {}

test "cli branches" {
    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const reader = std.Io.Reader.ending;
    const io = std.testing.io;

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
    try cli(io, &writer, reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, no_deps, std.testing.allocator);

    // git pull fails
    const fail_deps = Deps{
        .run = struct {
            fn f(_: std.Io, _: []const u8, _: tools.RunOpts) anyerror!i32 { return 1; }
        }.f,
        .confirm = mockConfirmTrue,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };
    try std.testing.expectError(error.GitPullFailed, cli(io, &writer, reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, fail_deps, std.testing.allocator));

    // update + diff + git changes + add
    try cli(io, &writer, reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = true, .diff = true }, deps, std.testing.allocator);

    // no git changes (diff returns 0)
    const no_changes_deps = Deps{
        .run = struct {
            fn f(_: std.Io, _: []const u8, _: tools.RunOpts) anyerror!i32 { return 0; }
        }.f,
        .confirm = mockConfirmTrue,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };
    try cli(io, &writer, reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, no_changes_deps, std.testing.allocator);
}

test "cli git add failure" {
    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const reader = std.Io.Reader.ending;
    const io = std.testing.io;

    const add_fail_deps = Deps{
        .run = struct {
            fn f(_: std.Io, c: []const u8, _: tools.RunOpts) anyerror!i32 {
                if (std.mem.indexOf(u8, c, "add .") != null) return error.MockError;
                if (std.mem.indexOf(u8, c, "diff --exit-code") != null) return 1;
                return 0;
            }
        }.f,
        .confirm = mockConfirmTrue,
        .printTitle = mockPrintTitle,
        .configPrint = mockConfigPrint,
    };

    try cli(io, &writer, reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = true }, add_fail_deps, std.testing.allocator);
}
