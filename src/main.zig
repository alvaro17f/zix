const std = @import("std");
const app = @import("app/app.zig").app;
const eql = std.mem.eql;

const version = "0.1.0";

pub const Cli = struct {
    repo: []const u8,
    // hostname: []const u8,
    update: bool,
    diff: bool,

    pub fn init() !Cli {
        return Cli{
            .repo = "~/.dotfiles",
            // .hostname = try std.os.getHostName(),
            .update = false,
            .diff = false,
        };
    }
};
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var cli = try Cli.init();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        return try app(cli);
    }

    for (args) |arg| {
        if (eql(u8, arg, "-h")) {
            return std.debug.print(
                \\
                \\ ***************************************************
                \\ ZIX - A simple CLI tool to update your nixos system
                \\ ***************************************************
                \\ -r : set repo path (default is $HOME/.dotfiles)
                \\ -u : set update to true (default is false)
                \\ -d : set diff to true (default is false)
                \\ -h : Display this help message
                \\ -v : Display the current version
                \\
            , .{});
        }

        if (eql(u8, arg, "-v")) {
            return std.debug.print("\nZIX version: {s}\n", .{version});
        }

        // if (eql(u8, arg, "-r")) {
        //     if (arg + 1 == args.len) {
        //         return std.debug.print("Error: -r flag requires an argument\n", .{});
        //     }
        //     Cli.repo = args[arg + 1];
        // }

        if (eql(u8, arg, "-u")) {
            cli.update = true;
        }

        if (eql(u8, arg, "-d")) {
            cli.diff = true;
        }

        // if (eql(u8, arg, "-n")) {
        // Cli.hostname = arg;
        // }

        return try app(cli);
    }
}
