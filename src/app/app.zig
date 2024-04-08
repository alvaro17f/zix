const std = @import("std");
const print = std.debug.print;
const tools = @import("../utils/tools.zig");
const cmd = @import("../utils/commands.zig");

pub fn app() !void {
    try tools.titleMaker("ZIX Configuration");
    print(cmd.configurationCmd, .{});

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
