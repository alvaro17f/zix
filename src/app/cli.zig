const std = @import("std");
const Arena = @import("allocator").Arena;
const fmt = @import("fmt");
const tools = @import("../utils/tools.zig");
const cmd = @import("../utils/commands.zig");
const Config = @import("init.zig").Config;
const style = @import("../utils/style.zig");

pub fn cli(config: Config) !void {
    try tools.titleMaker("ZIX Configuration");
    try cmd.configPrint(config);

    if (try tools.confirm(true, null)) {
        var arena = Arena.init();
        defer arena.deinit();
        const allocator = arena.allocator();

        try tools.titleMaker("Git Pull");
        const git_pull_status = try tools.run(try cmd.gitPull(allocator, config.repo), .{});

        if (git_pull_status != 0) {
            try fmt.print("{s}Failed to pull changes{s}\n", .{ style.Red, style.Reset });
            std.posix.exit(@intCast(git_pull_status));
        }

        if (config.update) {
            try tools.titleMaker("Nix Update");
            _ = try tools.run(try cmd.nixUpdate(allocator, config.repo), .{});
        }

        if (try tools.run(try cmd.gitDiff(allocator, config.repo), .{ .output = false }) == 1) {
            try tools.titleMaker("Git Changes");
            _ = try tools.run(try cmd.gitStatus(allocator, config.repo), .{});

            if (try tools.confirm(true, "Do you want to add these changes to the stage?")) {
                _ = tools.run(try cmd.gitAdd(allocator, config.repo), .{}) catch |err| {
                    try fmt.print("Failed to add changes to the stage: {}\n", .{err});
                };
                try fmt.print("{s}Changes added to git stage successfully{s}\n", .{ style.Green, style.Reset });
            }
        }

        try tools.titleMaker("Nixos Rebuild");
        _ = try tools.run(try cmd.nixRebuild(allocator, config.repo, config.hostname), .{});
        _ = try tools.run(try cmd.nixKeep(allocator, config.keep), .{});

        if (config.diff) {
            try tools.titleMaker("Nix Diff");
            _ = try tools.run(cmd.nixDiff, .{});
        }
    }
}
