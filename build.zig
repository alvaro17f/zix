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
        .link_libc = true,
    });

    const zon_mod = b.createModule(.{
        .root_source_file = b.path("build.zig.zon"),
    });
    exe_mod.addImport("zon", zon_mod);

    const exe = b.addExecutable(.{
        .name = "zix",
        .root_module = exe_mod,
        .version = version,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_mod.addImport("zon", zon_mod);

    const test_compile = b.addTest(.{
        .name = "zix-test",
        .root_module = test_mod,
        .use_llvm = true,
    });
    b.installArtifact(test_compile);

    const run_tests = b.addRunArtifact(test_compile);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
