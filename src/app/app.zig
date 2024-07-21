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
        try tools.runCmd(cmd.gitPullCmd);

        if (cli.update) return {
            try tools.titleMaker("Nix Update");
            try tools.runCmd(cmd.nixUpdateCmd);
        };

        const git_diff_exit_code = try tools.exitCode(cmd.gitDiffCmd);
        if (git_diff_exit_code == 1) {
            try tools.titleMaker("Git Changes");
            try tools.runCmd(cmd.gitStatusCmd);

            if (try tools.confirm(true, "Do you want to add these changes to the stage?")) {
                tools.runCmd(cmd.gitAddCmd) catch |err| {
                    print("Failed to add changes to the stage: {}\n", .{err});
                };
            }
        }

        try tools.titleMaker("Nixos Rebuild");
        try tools.runCmd(cmd.nixRebuildCmd);

        try tools.titleMaker("Nix Keep");
        try tools.runCmd(cmd.nixKeepCmd);

        if (cli.diff) return {
            try tools.titleMaker("Nix Diff");
            try tools.runCmd(cmd.nixDiffCmd);
        };
    }
}
