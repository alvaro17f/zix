const app = @import("app/app.zig").app;

pub fn main() !void {
    try app();
}
