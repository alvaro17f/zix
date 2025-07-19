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

pub fn gitPull(repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "git -C {s} pull", .{repo});
}

pub fn gitDiff(repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "git -C {s} diff --exit-code", .{repo});
}

pub fn gitStatus(repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "git -C {s} status --porcelain", .{repo});
}

pub fn gitAdd(repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "git -C {s} add .", .{repo});
}

pub fn nixUpdate(repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "cd {s} && nix flake update", .{repo});
}

pub fn nixRebuild(repo: []const u8, hostname: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "sudo nixos-rebuild switch --flake {s}#{s} --show-trace", .{ repo, hostname });
}

pub fn nixKeep(generations_to_keep: u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +{d}", .{generations_to_keep});
}

pub const nixDiff = "nix profile diff-closures --profile /nix/var/nix/profiles/system | tac | awk '/Version/{print; exit} 1' | tac";
