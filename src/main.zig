const std = @import("std");
const detectLeaks = @import("allocator").detectLeaks;
const app = @import("app/init.zig");
const builtin = @import("builtin");

pub fn main(init: std.process.Init) !void {
    defer if (detectLeaks() > 0) {
        std.process.exit(1);
    };

    var args_list: std.ArrayList([]const u8) = .empty;
    defer args_list.deinit(init.gpa);
    for (init.minimal.args.vector) |arg_z| {
        try args_list.append(init.gpa, std.mem.sliceTo(arg_z, 0));
    }

    var stdout_buf: [4096]u8 = undefined;
    const stdout_file = std.Io.File.stdout();
    var stdout_writer = stdout_file.writer(init.io, &stdout_buf);

    var stdin_buf: [1024]u8 = undefined;
    const stdin_file = std.Io.File.stdin();
    var stdin_reader = stdin_file.reader(init.io, &stdin_buf);

    try app.run(init.io, &stdout_writer.interface, &stdin_reader.interface, args_list.items);
}
