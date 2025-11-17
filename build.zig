const std = @import("std");
const zon = @import("build.zig.zon");

pub const version = std.SemanticVersion.parse(zon.version) catch @panic("Invalid version in build.zig.zon");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const fmt_mod = b.createModule(.{
        .root_source_file = b.path("src/utils/fmt.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("fmt", fmt_mod);

    const allocator_mod = b.createModule(.{
        .root_source_file = b.path("src/utils/allocator.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("allocator", allocator_mod);

    const zon_mod = b.createModule(.{
        .root_source_file = b.path("build.zig.zon"),
    });
    exe_mod.addImport("zon", zon_mod);

    const exe = b.addExecutable(.{
        .name = "zix",
        .root_module = exe_mod,
        .version = version,
    });

    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
