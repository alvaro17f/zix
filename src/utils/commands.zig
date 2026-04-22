const std = @import("std");
const fmt = @import("fmt.zig");
const style = @import("style.zig");
const builtin = @import("builtin");
const Config = @import("../app/init.zig").Config;

fn printConfigLine(writer: *std.Io.Writer, label: []const u8, value: anytype, options: struct { new_line: bool = true }) !void {
    const value_fmt = comptime if (@TypeOf(value) == []const u8) "{s}" else "{}";
    try fmt.printTo(writer, "{s}◉ {s}{s}{s} = {s}" ++ value_fmt ++ "{s}{s}", .{
        style.Cyan,
        style.Red,
        label,
        style.Reset,
        style.Cyan,
        value,
        style.Reset,
        if (options.new_line) "\n" else "",
    });
}

pub fn configPrint(writer: *std.Io.Writer, config: Config) !void {
    const fields = @typeInfo(Config).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        const is_last = i == fields.len - 1;
        const value = @field(config, field.name);
        try printConfigLine(writer, field.name, value, .{ .new_line = !is_last });
    }
}

pub fn gitPull(allocator: std.mem.Allocator, repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "git -C {s} pull", .{repo});
}

pub fn gitDiff(allocator: std.mem.Allocator, repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "git -C {s} diff --exit-code", .{repo});
}

pub fn gitStatus(allocator: std.mem.Allocator, repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "git -C {s} status --porcelain", .{repo});
}

pub fn gitAdd(allocator: std.mem.Allocator, repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "git -C {s} add .", .{repo});
}

pub fn nixUpdate(allocator: std.mem.Allocator, repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "nix flake update --flake {s}", .{repo});
}

pub fn nixRebuild(allocator: std.mem.Allocator, repo: []const u8, hostname: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "sudo nixos-rebuild switch --flake {s}#{s} --show-trace", .{ repo, hostname });
}

pub fn nixKeep(allocator: std.mem.Allocator, generations_to_keep: u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +{d}", .{generations_to_keep});
}

pub const nixDiff = "nix profile diff-closures --profile /nix/var/nix/profiles/system | tac | awk '/Version/{print; exit} 1' | tac";

test "command strings" {
    const alloc = std.testing.allocator;
    const s0 = try gitPull(alloc, "/repo");
    defer alloc.free(s0);
    try std.testing.expectEqualStrings("git -C /repo pull", s0);
    const s1 = try gitDiff(alloc, "/repo");
    defer alloc.free(s1);
    try std.testing.expectEqualStrings("git -C /repo diff --exit-code", s1);
    const s2 = try gitStatus(alloc, "/repo");
    defer alloc.free(s2);
    try std.testing.expectEqualStrings("git -C /repo status --porcelain", s2);
    const s3 = try gitAdd(alloc, "/repo");
    defer alloc.free(s3);
    try std.testing.expectEqualStrings("git -C /repo add .", s3);
    const s4 = try nixUpdate(alloc, "/repo");
    defer alloc.free(s4);
    try std.testing.expectEqualStrings("nix flake update --flake /repo", s4);
    const s5 = try nixRebuild(alloc, "/repo", "host");
    defer alloc.free(s5);
    try std.testing.expectEqualStrings("sudo nixos-rebuild switch --flake /repo#host --show-trace", s5);
    const s6 = try nixKeep(alloc, 5);
    defer alloc.free(s6);
    try std.testing.expectEqualStrings("sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +5", s6);
}

test "configPrint renders all fields" {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    const config = Config{
        .repo = "~/.dotfiles",
        .hostname = "nixos",
        .keep = 10,
        .update = false,
        .diff = true,
    };
    try configPrint(&writer, config);
    try std.testing.expect(std.mem.indexOf(u8, &buf, "repo") != null);
    try std.testing.expect(std.mem.indexOf(u8, &buf, "hostname") != null);
    try std.testing.expect(std.mem.indexOf(u8, &buf, "keep") != null);
    try std.testing.expect(std.mem.indexOf(u8, &buf, "update") != null);
    try std.testing.expect(std.mem.indexOf(u8, &buf, "diff") != null);
}
