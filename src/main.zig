const std = @import("std");
const app = @import("app/app.zig").app;
const eql = std.mem.eql;

const version = "0.1.0";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        return try app();
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
    }
}
