const std = @import("std");
const Arena = @import("../utils/allocator.zig").Arena;
const fmt = @import("../utils/fmt.zig");
const cmd = @import("../utils/commands.zig");
const Config = @import("init.zig").Config;
const style = @import("../utils/style.zig");

pub const RunOpts = struct { output: bool = true };

pub const Deps = struct {
    run: *const fn (std.Io, []const u8, RunOpts) anyerror!i32,
    confirm: *const fn (*std.Io.Reader, *std.Io.Writer, bool, ?[]const u8) anyerror!bool,
    titleMaker: *const fn (*std.Io.Writer, []const u8) anyerror!void,
    configPrint: *const fn (*std.Io.Writer, Config) anyerror!void,
};

pub fn cli(io: std.Io, writer: *std.Io.Writer, reader: *std.Io.Reader, config: Config, deps: Deps) !void {
    var arena = Arena.init();
    defer arena.deinit();
    const allocator = arena.allocator();

    try deps.titleMaker(writer, "ZIX Configuration");
    try deps.configPrint(writer, config);

    if (try deps.confirm(reader, writer, true, null)) {
        try deps.titleMaker(writer, "Git Pull");
        const git_pull_status = try deps.run(io, try cmd.gitPull(allocator, config.repo), .{});

        if (git_pull_status != 0) {
            try fmt.printTo(writer, "{s}Failed to pull changes{s}\n", .{ style.Red, style.Reset });
            return error.GitPullFailed;
        }

        if (config.update) {
            try deps.titleMaker(writer, "Nix Update");
            _ = try deps.run(io, try cmd.nixUpdate(allocator, config.repo), .{});
        }

        if (try deps.run(io, try cmd.gitDiff(allocator, config.repo), .{ .output = false }) == 1) {
            try deps.titleMaker(writer, "Git Changes");
            _ = try deps.run(io, try cmd.gitStatus(allocator, config.repo), .{});

            if (try deps.confirm(reader, writer, true, "Do you want to add these changes to the stage?")) {
                _ = deps.run(io, try cmd.gitAdd(allocator, config.repo), .{}) catch |err| { try fmt.printTo(writer, "Failed to add changes to the stage: {}\n", .{err}); };
                try fmt.printTo(writer, "\n{s}Changes added to git stage successfully{s}\n", .{ style.Green, style.Reset });
            }
        }

        try deps.titleMaker(writer, "Nixos Rebuild");
        _ = try deps.run(io, try cmd.nixRebuild(allocator, config.repo, config.hostname), .{});
        _ = try deps.run(io, try cmd.nixKeep(allocator, config.keep), .{});

        if (config.diff) {
            try deps.titleMaker(writer, "Nix Diff");
            _ = try deps.run(io, cmd.nixDiff, .{});
        }
    }
}

fn mockRun(_: std.Io, c: []const u8, _: RunOpts) anyerror!i32 {
    if (std.mem.startsWith(u8, c, "git -C")) {
        if (std.mem.indexOf(u8, c, "diff --exit-code") != null) return 1;
    }
    return 0;
}
fn mockConfirmTrue(_: *std.Io.Reader, _: *std.Io.Writer, _: bool, _: ?[]const u8) anyerror!bool { return true; }
fn mockConfirmFalse(_: *std.Io.Reader, _: *std.Io.Writer, _: bool, _: ?[]const u8) anyerror!bool { return false; }
fn mockTitleMaker(_: *std.Io.Writer, _: []const u8) anyerror!void {}
fn mockConfigPrint(_: *std.Io.Writer, _: Config) anyerror!void {}

test "cli branches" {
    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const reader = std.Io.Reader.ending;
    const io = std.testing.io;

    const deps = Deps{
        .run = mockRun,
        .confirm = mockConfirmTrue,
        .titleMaker = mockTitleMaker,
        .configPrint = mockConfigPrint,
    };

    // confirm false => early return
    const no_deps = Deps{
        .run = mockRun,
        .confirm = mockConfirmFalse,
        .titleMaker = mockTitleMaker,
        .configPrint = mockConfigPrint,
    };
    try cli(io, &writer, reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, no_deps);

    // git pull fails
    const fail_deps = Deps{
        .run = struct {
            fn f(_: std.Io, _: []const u8, _: RunOpts) anyerror!i32 { return 1; }
        }.f,
        .confirm = mockConfirmTrue,
        .titleMaker = mockTitleMaker,
        .configPrint = mockConfigPrint,
    };
    try std.testing.expectError(error.GitPullFailed, cli(io, &writer, reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = false }, fail_deps));

    // update + diff + git changes + add
    try cli(io, &writer, reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = true, .diff = true }, deps);
}

test "cli git add failure" {
    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const reader = std.Io.Reader.ending;
    const io = std.testing.io;

    const add_fail_deps = Deps{
        .run = struct {
            fn f(_: std.Io, c: []const u8, _: RunOpts) anyerror!i32 {
                if (std.mem.indexOf(u8, c, "git add") != null) return error.MockError;
                if (std.mem.indexOf(u8, c, "diff --exit-code") != null) return 1;
                return 0;
            }
        }.f,
        .confirm = mockConfirmTrue,
        .titleMaker = mockTitleMaker,
        .configPrint = mockConfigPrint,
    };

    try cli(io, &writer, reader, Config{ .repo = "r", .hostname = "h", .keep = 1, .update = false, .diff = true }, add_fail_deps);
}
