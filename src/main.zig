const std = @import("std");
const detectLeaks = @import("allocator").detectLeaks;
const app = @import("app/init.zig");
const builtin = @import("builtin");

pub const VERSION = "dev";

pub fn main() !void {
    defer if (detectLeaks()) {
        std.posix.exit(1);
    };

    try app.init();
}
