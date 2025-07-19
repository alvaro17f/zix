const std = @import("std");
const print = std.debug.print;
const tools = @import("../utils/tools.zig");
const cmd = @import("../utils/commands.zig");
const Config = @import("init.zig").Config;

pub fn cli(config: Config) !void {
    try tools.titleMaker("ZIX Configuration");
    cmd.configPrint(config.repo, config.hostname, config.keep, tools.boolToString(config.update), tools.boolToString(config.diff));

    if (try tools.confirm(true, null)) {
        try tools.titleMaker("Git Pull");
        _ = try tools.runCmd(.{ .command = try cmd.gitPullCmd(config.repo) });

        if (config.update) {
            try tools.titleMaker("Nix Update");
            _ = try tools.runCmd(.{ .command = try cmd.nixUpdateCmd(config.repo) });
        }

        if (try tools.runCmd(.{ .command = try cmd.gitDiffCmd(config.repo), .output = false }) == 1) {
            try tools.titleMaker("Git Changes");
            _ = try tools.runCmd(.{ .command = try cmd.gitStatusCmd(config.repo) });

            if (try tools.confirm(true, "Do you want to add these changes to the stage?")) {
                _ = tools.runCmd(.{ .command = try cmd.gitAddCmd(config.repo) }) catch |err| {
                    print("Failed to add changes to the stage: {}\n", .{err});
                };
            }
        }

        try tools.titleMaker("Nixos Rebuild");
        _ = try tools.runCmd(.{ .command = try cmd.nixRebuildCmd(config.repo, config.hostname) });
        _ = try tools.runCmd(.{ .command = try cmd.nixKeepCmd(config.keep) });

        if (config.diff) {
            try tools.titleMaker("Nix Diff");
            _ = try tools.runCmd(.{ .command = cmd.nixDiffCmd });
        }
    }
}
