const std = @import("std");

pub const gitPullCmd = std.fmt.comptimePrint("git -C {s} pull", .{"~/.dotfiles"});
pub const gitDiffCmd = std.fmt.comptimePrint("git -C {s} diff --exit-code", .{"~/.dotfiles"});
pub const gitStatusCmd = std.fmt.comptimePrint("git -C {s} status --porcelain", .{"~/.dotfiles"});
pub const gitAddCmd = std.fmt.comptimePrint("git -C {s} add .", .{"~/.dotfiles"});
pub const nixUpdateCmd = std.fmt.comptimePrint("cd {s} && nix flake update", .{"~/.dotfiles"});
pub const nixRebuildCmd = std.fmt.comptimePrint("sudo nixos-rebuild switch --flake {s}#{s} --show-trace", .{ "~/.dotfiles", "zenon" });
pub const nixKeepCmd = std.fmt.comptimePrint("sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +{d}", .{10});
pub const nixDiffCmd = "nix profile diff-closures --profile /nix/var/nix/profiles/system | tac | awk '/Version/{print; exit} 1' | tac";
pub fn configPrint(repo: []const u8, update: []const u8, diff: []const u8, hostname: []const u8) void {
    std.debug.print(
        \\ repo = {s}
        \\ update = {s}
        \\ diff = {s}
        \\ hostname = {s}
    , .{ repo, update, diff, hostname });
}
