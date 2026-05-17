const std = @import("std");
const app = @import("app/init.zig");
const cli = @import("app/cli.zig");
const ui = @import("core/ui.zig");
const process = @import("core/process.zig");

pub fn main(init: std.process.Init) !void {
    var args_list: std.ArrayList([]const u8) = .empty;
    defer args_list.deinit(init.gpa);
    for (init.minimal.args.vector) |arg_z| {
        try args_list.append(init.gpa, std.mem.sliceTo(arg_z, 0));
    }

    var stdout_buf: [4096]u8 = undefined;
    const stdout_file = std.Io.File.stdout();
    var stdout_writer = stdout_file.writer(init.io, &stdout_buf);

    // Dependency injection: all side effects go through Deps for testability.
    const deps = cli.Deps{
        .run = process.run,
        .confirm = ui.confirm,
        .printTitle = ui.printTitle,
        .configPrint = ui.configPrint,
    };

    try app.run(init.io, &stdout_writer.interface, args_list.items, deps, init.gpa);
}

test {
    _ = @import("app/init.zig");
    _ = @import("app/config.zig");
    _ = @import("app/cli.zig");
    _ = @import("core/io.zig");
    _ = @import("core/commands.zig");
    _ = @import("core/ui.zig");
    _ = @import("core/process.zig");
    _ = @import("zon");
}
