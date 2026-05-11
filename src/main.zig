const std = @import("std");
const app = @import("app/init.zig");
const cli = @import("app/cli.zig");
const tools = @import("utils/tools.zig");
const cmd = @import("utils/commands.zig");

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

    var stdin_buf: [1024]u8 = undefined;
    const stdin_file = std.Io.File.stdin();
    var stdin_reader = stdin_file.reader(init.io, &stdin_buf);

    const deps = cli.Deps{
        .run = tools.run,
        .confirm = tools.confirm,
        .printTitle = tools.printTitle,
        .configPrint = cmd.configPrint,
    };

    try app.run(init.io, &stdout_writer.interface, &stdin_reader.interface, args_list.items, deps, alloc);
}

test {
    _ = @import("app/init.zig");
    _ = @import("app/cli.zig");
    _ = @import("utils/fmt.zig");
    _ = @import("utils/style.zig");
    _ = @import("utils/commands.zig");
    _ = @import("utils/tools.zig");
    _ = @import("zon");
}
