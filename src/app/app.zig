const std = @import("std");
const print = std.debug.print;
const tools = @import("../utils/tools.zig");
const cmd = @import("../utils/commands.zig").cmd;
const Cli = @import("../main.zig").Cli;

pub fn app(cli: Cli) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try tools.titleMaker("ZIX Configuration");
    cmd.configPrint(cli.repo, cli.hostname, cli.keep, tools.boolToString(cli.update), tools.boolToString(cli.diff));

    if (try tools.confirm(true, null)) {
        try tools.titleMaker("Git Pull");
        _ = try tools.runCmd(true, try cmd.gitPullCmd(allocator, cli.repo));

        if (cli.update) {
            try tools.titleMaker("Nix Update");
            _ = try tools.runCmd(true, try cmd.nixUpdateCmd(allocator, cli.repo));
        }

        if (try tools.runCmd(false, try cmd.gitDiffCmd(allocator, cli.repo)) == 1) {
            try tools.titleMaker("Git Changes");
            _ = try tools.runCmd(true, try cmd.gitStatusCmd(allocator, cli.repo));

            if (try tools.confirm(true, "Do you want to add these changes to the stage?")) {
                _ = tools.runCmd(true, try cmd.gitAddCmd(allocator, cli.repo)) catch |err| {
                    print("Failed to add changes to the stage: {}\n", .{err});
                };
            }
        }

        try tools.titleMaker("Nixos Rebuild");
        _ = try tools.runCmd(true, try cmd.nixRebuildCmd(allocator, cli.repo, cli.hostname));
        _ = try tools.runCmd(true, try cmd.nixKeepCmd(allocator, cli.keep));

        if (cli.diff) {
            try tools.titleMaker("Nix Diff");
            _ = try tools.runCmd(true, cmd.nixDiffCmd);
        }
    }
}
