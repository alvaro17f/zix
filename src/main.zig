const std = @import("std");
const app = @import("app/app.zig").app;
const eql = std.mem.eql;

const version = "0.1.0";

pub const Cli = struct {
    repo: []const u8,
    hostname: []const u8,
    update: bool,
    diff: bool,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var name_buffer: [std.os.linux.HOST_NAME_MAX]u8 = undefined;

    var cli = Cli{
        .repo = "~/.dotfiles",
        .hostname = std.posix.gethostname(&name_buffer) catch "unknown",
        .update = false,
        .diff = false,
    };

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        return try app(cli);
    }

    for (args, 0..) |arg, idx| {
        if (eql(u8, arg, "-h")) {
            return std.debug.print(
                \\
                \\ ***************************************************
                \\ ZIX - A simple CLI tool to update your nixos system
                \\ ***************************************************
                \\ -r : set repo path (default is $HOME/.dotfiles)
                \\ -n : set hostname (default is OS hostname)
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

        if (eql(u8, arg, "-r")) {
            if (idx + 1 >= args.len) {
                return std.debug.print("Error: -r flag requires an argument\n", .{});
            }

            cli.repo = args[idx + 1];
        }

        if (eql(u8, arg, "-u")) {
            cli.update = true;
        }

        if (eql(u8, arg, "-d")) {
            cli.diff = true;
        }

        if (eql(u8, arg, "-n")) {
            if (idx + 1 >= args.len) {
                return std.debug.print("Error: -n flag requires an argument\n", .{});
            }

            cli.hostname = args[idx + 1];
        }
    }

    return try app(cli);
}
