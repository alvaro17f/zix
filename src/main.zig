const std = @import("std");
const allocator = @import("allocator");
const app = @import("app/init.zig");
const builtin = @import("builtin");

pub const VERSION = "dev";

pub fn main() !void {
    try app.init();
    if (allocator.detectLeaks()) {
        std.posix.exit(1);
    }
}
