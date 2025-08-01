const std = @import("std");
const allocator = @import("allocator").allocator;
const fmt = @import("fmt");
const cli = @import("./cli.zig").cli;
const eql = std.mem.eql;
const style = @import("../utils/style.zig");
const VERSION = @import("root").VERSION;

pub const Config = struct {
    repo: []const u8,
    hostname: []const u8,
    keep: u8,
    update: bool,
    diff: bool,
};

fn printHelp() !void {
    try fmt.print(
        \\
        \\ *****************************************************
        \\  ZIX - A simple CLI tool to update your nixos system
        \\ *****************************************************
        \\ -r : set repo path (default is $HOME/.dotfiles)
        \\ -n : set hostname (default is OS hostname)
        \\ -k : set generations to keep (default is 10)
        \\ -u : set update to true (default is false)
        \\ -d : set diff to true (default is false)
        \\ -h, help : Display this help message
        \\ -v, version : Display the current version
        \\
        \\
    , .{});
}

fn printVersion() !void {
    try fmt.print("{s}\nZIX version: {s}{s}\n{s}", .{ style.Yellow, style.Cyan, VERSION, style.Reset });
}

fn getHostname(buffer: *[64]u8) []const u8 {
    return std.posix.gethostname(buffer) catch "unknown";
}

pub fn init() !void {
    var hostname_buffer: [std.os.linux.HOST_NAME_MAX]u8 = undefined;

    var config = Config{
        .repo = "~/.dotfiles",
        .hostname = getHostname(&hostname_buffer),
        .keep = 10,
        .update = false,
        .diff = false,
    };

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        return try cli(config);
    }

    for (args[1..], 0..) |arg, idx| {
        if (arg[0] == '-') {
            for (arg[1..]) |flag| {
                switch (flag) {
                    'h' => {
                        return try printHelp();
                    },
                    'v' => {
                        return try printVersion();
                    },
                    'd' => config.diff = true,
                    'u' => config.update = true,
                    'r', 'n', 'k' => {
                        if (idx + 2 >= args.len) {
                            return try fmt.print("{s}Error: \"-{c}\" flag requires an argument\n{s}", .{ style.Red, flag, style.Reset });
                        }
                        if (flag == 'r') config.repo = args[idx + 2];
                        if (flag == 'n') config.hostname = args[idx + 2];
                        if (flag == 'k') {
                            const argument = args[idx + 2];
                            const number = std.fmt.parseInt(u8, argument, 10) catch {
                                return try fmt.print("{s}Error: Value of \"-k\" flag is not numeric.\n{s}", .{ style.Red, style.Reset });
                            };
                            config.keep = number;
                        }
                    },
                    else => return try fmt.print("{s}Error: Unknown flag \"-{c}\"\n{s}", .{ style.Red, flag, style.Reset }),
                }
            }
        } else if (idx == 0) {
            for (args[1..]) |argument| {
                if (eql(u8, argument, "help")) {
                    return try printHelp();
                }
                if (eql(u8, argument, "version")) {
                    return try printVersion();
                }

                return try fmt.print("{s}Error: Unknown argument \"{s}\"\n{s}", .{ style.Red, argument, style.Reset });
            }
        }
    }

    return try cli(config);
}
