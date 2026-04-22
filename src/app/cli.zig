const std = @import("std");
const Arena = @import("allocator").Arena;
const fmt = @import("fmt");
const tools = @import("../utils/tools.zig");
const cmd = @import("../utils/commands.zig");
const Config = @import("init.zig").Config;
const style = @import("../utils/style.zig");

pub const Deps = struct {
    run: *const fn (std.Io, []const u8, struct { output: bool = true }) anyerror!i32,
    confirm: *const fn (*std.Io.Reader, *std.Io.Writer, comptime default_value: bool, comptime msg: ?[]const u8) anyerror!bool,
    titleMaker: *const fn (*std.Io.Writer, []const u8) anyerror!void,
    configPrint: *const fn (*std.Io.Writer, Config) anyerror!void,
};

pub fn cli(io: std.Io, writer: *std.Io.Writer, reader: *std.Io.Reader, config: Config) !void {
    var arena = Arena.init();
    defer arena.deinit();
    const allocator = arena.allocator();

    try tools.titleMaker(writer, "ZIX Configuration");
    try cmd.configPrint(writer, config);

    if (try tools.confirm(reader, writer, true, null)) {
        try tools.titleMaker(writer, "Git Pull");
        const git_pull_status = try tools.run(io, try cmd.gitPull(allocator, config.repo), .{});

        if (git_pull_status != 0) {
            try fmt.printTo(writer, "{s}Failed to pull changes{s}\n", .{ style.Red, style.Reset });
            std.process.exit(@intCast(git_pull_status));
        }

        if (config.update) {
            try tools.titleMaker(writer, "Nix Update");
            _ = try tools.run(io, try cmd.nixUpdate(allocator, config.repo), .{});
        }

        if (try tools.run(io, try cmd.gitDiff(allocator, config.repo), .{ .output = false }) == 1) {
            try tools.titleMaker(writer, "Git Changes");
            _ = try tools.run(io, try cmd.gitStatus(allocator, config.repo), .{});

            if (try tools.confirm(reader, writer, true, "Do you want to add these changes to the stage?")) {
                _ = tools.run(io, try cmd.gitAdd(allocator, config.repo), .{}) catch |err| {
                    try fmt.printTo(writer, "Failed to add changes to the stage: {}\n", .{err});
                };
                try fmt.printTo(writer, "{s}Changes added to git stage successfully{s}\n", .{ style.Green, style.Reset });
            }
        }

        try tools.titleMaker(writer, "Nixos Rebuild");
        _ = try tools.run(io, try cmd.nixRebuild(allocator, config.repo, config.hostname), .{});
        _ = try tools.run(io, try cmd.nixKeep(allocator, config.keep), .{});

        if (config.diff) {
            try tools.titleMaker(writer, "Nix Diff");
            _ = try tools.run(io, cmd.nixDiff, .{});
        }
    }
}
