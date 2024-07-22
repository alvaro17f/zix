const std = @import("std");
const app = @import("app/app.zig").app;
const eql = std.mem.eql;
const style = @import("utils/style.zig").Style;

const version = "0.1.0";

pub const Cli = struct {
    repo: []const u8,
    hostname: []const u8,
    keep: u8,
    update: bool,
    diff: bool,
};

fn printHelp() void {
    std.debug.print(
        \\
        \\ ***************************************************
        \\ ZIX - A simple CLI tool to update your nixos system
        \\ ***************************************************
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

fn printVersion() void {
    std.debug.print("{s}\nZIX version: {s}{s}\n{s}", .{ style.Black, style.Cyan, version, style.Reset });
}

fn getHostname(buffer: *[64]u8) []const u8 {
    return std.posix.gethostname(buffer) catch "unknown";
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var hostname_buffer: [std.os.linux.HOST_NAME_MAX]u8 = undefined;

    var cli = Cli{
        .repo = "~/.dotfiles",
        .hostname = getHostname(&hostname_buffer),
        .keep = 10,
        .update = false,
        .diff = false,
    };

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        return try app(cli);
    }

    for (args[1..], 0..) |arg, idx| {
        if (arg[0] == '-') {
            for (arg[1..]) |flag| {
                switch (flag) {
                    'h' => {
                        return printHelp();
                    },
                    'v' => {
                        return printVersion();
                    },
                    'd' => cli.diff = true,
                    'u' => cli.update = true,
                    'r', 'n', 'k' => {
                        if (idx + 2 >= args.len) {
                            return std.debug.print("{s}Error: \"-{c}\" flag requires an argument\n{s}", .{ style.Red, flag, style.Reset });
                        }
                        if (flag == 'r') cli.repo = args[idx + 2];
                        if (flag == 'n') cli.hostname = args[idx + 2];
                        if (flag == 'k') {
                            const argument = args[idx + 2];
                            const number = std.fmt.parseInt(u8, argument, 10) catch {
                                return std.debug.print("{s}Error: Value of \"-k\" flag is not numeric.\n{s}", .{ style.Red, style.Reset });
                            };
                            cli.keep = number;
                        }
                    },
                    else => return std.debug.print("{s}Error: Unknown flag \"-{c}\"\n{s}", .{ style.Red, flag, style.Reset }),
                }
            }
        } else if (idx == 0) {
            for (args[1..]) |argument| {
                if (eql(u8, argument, "help")) {
                    return printHelp();
                }
                if (eql(u8, argument, "version")) {
                    return printVersion();
                }

                return std.debug.print("{s}Error: Unknown argument \"{s}\"\n{s}", .{ style.Red, argument, style.Reset });
            }
        }
    }

    return try app(cli);
}
