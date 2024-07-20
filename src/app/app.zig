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

        try tools.titleMaker("Nix Update");
        try tools.titleMaker("Git Changes");
        try tools.titleMaker("Nixos Rebuild");
        try tools.titleMaker("Nix Diff");
        try tools.runCmd(cmd.nixDiffCmd);

        try tools.titleMaker("Current Directory");
        try tools.runCmd("ls -a");
    }
}
