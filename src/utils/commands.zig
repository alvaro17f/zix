const std = @import("std");
const style = @import("style.zig");
const builtin = @import("builtin");

const allocator = if (builtin.mode == .Debug) std.heap.page_allocator else std.heap.c_allocator;

pub fn configPrint(repo: []const u8, hostname: []const u8, keep: u8, update: []const u8, diff: []const u8) void {
    std.debug.print(
        \\ {s}◉{s} repo{s} = {s}{s}{s}
        \\ {s}◉{s} hostname{s} = {s}{s}{s}
        \\ {s}◉{s} keep{s} = {s}{d}{s}
        \\ {s}◉{s} update{s} = {s}{s}{s}
        \\ {s}◉{s} diff{s} = {s}{s}{s}
    , .{ style.Black, style.Red, style.Reset, style.Cyan, repo, style.Reset, style.Black, style.Red, style.Reset, style.Cyan, hostname, style.Reset, style.Black, style.Red, style.Reset, style.Cyan, keep, style.Reset, style.Black, style.Red, style.Reset, style.Cyan, update, style.Reset, style.Black, style.Red, style.Reset, style.Cyan, diff, style.Reset });
}

pub fn gitPullCmd(repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "git -C {s} pull", .{repo});
}

pub fn gitDiffCmd(repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "git -C {s} diff --exit-code", .{repo});
}

pub fn gitStatusCmd(repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "git -C {s} status --porcelain", .{repo});
}

pub fn gitAddCmd(repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "git -C {s} add .", .{repo});
}

pub fn nixUpdateCmd(repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "cd {s} && nix flake update", .{repo});
}

pub fn nixRebuildCmd(repo: []const u8, hostname: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "sudo nixos-rebuild switch --flake {s}#{s} --show-trace", .{ repo, hostname });
}

pub fn nixKeepCmd(generations_to_keep: u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +{d}", .{generations_to_keep});
}

pub const nixDiffCmd = "nix profile diff-closures --profile /nix/var/nix/profiles/system | tac | awk '/Version/{print; exit} 1' | tac";
