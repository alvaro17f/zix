const std = @import("std");
const app = @import("app/init.zig");
const builtin = @import("builtin");

pub const VERSION = "dev";

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const allocator = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.c_allocator;

    defer if (builtin.mode == .Debug) {
        if (debug_allocator.detectLeaks()) {
            std.posix.exit(1);
        }
    };

    try app.init(allocator);
}
