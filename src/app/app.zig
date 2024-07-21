const std = @import("std");
const print = std.debug.print;
const tools = @import("../utils/tools.zig");
const cmd = @import("../utils/commands.zig");
const Cli = @import("../main.zig").Cli;

pub fn app(cli: Cli) !void {
    try tools.titleMaker("ZIX Configuration");
    cmd.configPrint(cli.repo, tools.boolToString(cli.update), tools.boolToString(cli.diff), cli.hostname);

    if (try tools.confirm(true, null)) {
        try tools.titleMaker("Git Pull");
        _ = try tools.runCmd(true, cmd.gitPullCmd);

        if (cli.update) {
            try tools.titleMaker("Nix Update");
            _ = try tools.runCmd(true, cmd.nixUpdateCmd);
        }

        if (try tools.runCmd(false, cmd.gitDiffCmd) == 1) {
            try tools.titleMaker("Git Changes");
            _ = try tools.runCmd(true, cmd.gitStatusCmd);

            if (try tools.confirm(true, "Do you want to add these changes to the stage?")) {
                _ = tools.runCmd(true, cmd.gitAddCmd) catch |err| {
                    print("Failed to add changes to the stage: {}\n", .{err});
                };
            }
        }

        try tools.titleMaker("Nixos Rebuild");
        _ = try tools.runCmd(true, cmd.nixRebuildCmd);

        if (try tools.runCmd(false, cmd.nixKeepCmd) == 1) {
            _ = try tools.runCmd(true, cmd.nixKeepCmd);
        }

        if (cli.diff) {
            try tools.titleMaker("Nix Diff");
            _ = try tools.runCmd(true, cmd.nixDiffCmd);
        }
    }
}
