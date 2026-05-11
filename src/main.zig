const std = @import("std");
const app = @import("app/init.zig");
const cli = @import("app/cli.zig");
const ui = @import("core/ui.zig");
const process = @import("core/process.zig");

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;

    var args_list: std.ArrayList([]const u8) = .empty;
    defer args_list.deinit(alloc);
    for (init.minimal.args.vector) |arg_z| {
        try args_list.append(alloc, std.mem.sliceTo(arg_z, 0));
    }

    var stdout_buf: [4096]u8 = undefined;
    const stdout_file = std.Io.File.stdout();
    var stdout_writer = stdout_file.writer(init.io, &stdout_buf);

    const deps = cli.Deps{
        .run = process.run,
        .confirm = ui.confirm,
        .printTitle = ui.printTitle,
        .configPrint = app.configPrint,
    };

    try app.run(init.io, &stdout_writer.interface, args_list.items, deps, alloc);
}

test {
    _ = @import("app/init.zig");
    _ = @import("app/cli.zig");
    _ = @import("core/io.zig");
    _ = @import("core/commands.zig");
    _ = @import("core/ui.zig");
    _ = @import("core/process.zig");
    _ = @import("zon");
}
