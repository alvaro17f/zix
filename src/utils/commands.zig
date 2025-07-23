const std = @import("std");
const style = @import("style.zig");
const builtin = @import("builtin");
const Config = @import("../app/init.zig").Config;

const allocator = if (builtin.mode == .Debug) std.heap.page_allocator else std.heap.c_allocator;

fn printConfigLine(label: []const u8, value: anytype, options: struct { new_line: bool = true }) void {
    const value_fmt = comptime if (@TypeOf(value) == []const u8) "{s}" else "{}";

    std.debug.print("{s}◉ {s}{s}{s} = {s}" ++ value_fmt ++ "{s}{s}", .{
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

pub fn configPrint(config: Config) void {
    const fields = @typeInfo(Config).@"struct".fields;

    inline for (fields, 0..) |field, i| {
        const is_last = i == fields.len - 1;
        const value = @field(config, field.name);

        printConfigLine(field.name, value, .{ .new_line = !is_last });
    }
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
    return std.fmt.allocPrint(allocator, "nix flake update --flake {s}", .{repo});
}

pub fn nixRebuild(repo: []const u8, hostname: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "sudo nixos-rebuild switch --flake {s}#{s} --show-trace", .{ repo, hostname });
}

pub fn nixKeep(generations_to_keep: u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +{d}", .{generations_to_keep});
}

pub const nixDiff = "nix profile diff-closures --profile /nix/var/nix/profiles/system | tac | awk '/Version/{print; exit} 1' | tac";
