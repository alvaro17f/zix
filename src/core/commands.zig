const std = @import("std");

// Maximum command string length. All commands must fit within this limit.
pub const MAX_COMMAND_LEN: u32 = 256;

pub fn gitPull(buf: []u8, repo: []const u8) ![]const u8 {
    // Assert preconditions: repo must be a valid path, buffer must be large enough.
    std.debug.assert(repo.len > 0);
    std.debug.assert(buf.len >= MAX_COMMAND_LEN);
    return std.fmt.bufPrint(buf, "git -C {s} pull", .{repo});
}

pub fn gitDiff(buf: []u8, repo: []const u8) ![]const u8 {
    std.debug.assert(repo.len > 0);
    std.debug.assert(buf.len >= MAX_COMMAND_LEN);
    return std.fmt.bufPrint(buf, "git -C {s} diff --exit-code", .{repo});
}

pub fn gitStatus(buf: []u8, repo: []const u8) ![]const u8 {
    std.debug.assert(repo.len > 0);
    std.debug.assert(buf.len >= MAX_COMMAND_LEN);
    return std.fmt.bufPrint(buf, "git -C {s} status --porcelain", .{repo});
}

pub fn gitAdd(buf: []u8, repo: []const u8) ![]const u8 {
    std.debug.assert(repo.len > 0);
    std.debug.assert(buf.len >= MAX_COMMAND_LEN);
    return std.fmt.bufPrint(buf, "git -C {s} add .", .{repo});
}

pub fn nixUpdate(buf: []u8, repo: []const u8) ![]const u8 {
    std.debug.assert(repo.len > 0);
    std.debug.assert(buf.len >= MAX_COMMAND_LEN);
    return std.fmt.bufPrint(buf, "nix flake update --flake {s}", .{repo});
}

pub fn nixRebuild(
    buf: []u8,
    repo: []const u8,
    hostname: []const u8,
) ![]const u8 {
    // Assert preconditions: repo and hostname must be valid.
    std.debug.assert(repo.len > 0);
    std.debug.assert(hostname.len > 0);
    std.debug.assert(buf.len >= MAX_COMMAND_LEN);
    return std.fmt.bufPrint(
        buf,
        "sudo nixos-rebuild switch --flake {s}#{s} --show-trace",
        .{ repo, hostname },
    );
}

pub fn nixKeep(
    buf: []u8,
    generations_to_keep: u8,
) ![]const u8 {
    // generations_to_keep must be > 0 to be meaningful.
    std.debug.assert(generations_to_keep > 0);
    std.debug.assert(buf.len >= MAX_COMMAND_LEN);
    return std.fmt.bufPrint(
        buf,
        "sudo nix-env --profile /nix/var/nix/profiles/system" ++ " --delete-generations +{d}",
        .{generations_to_keep},
    );
}

const nix_diff_profile = " --profile /nix/var/nix/profiles/system";
const nix_diff_awk = " | awk '/Version/{print; exit} 1'";

pub const nixDiff =
    "nix profile diff-closures" ++ nix_diff_profile ++ " | tac" ++ nix_diff_awk ++ " | tac";

test "command strings" {
    var buf: [MAX_COMMAND_LEN]u8 = undefined;
    const s0 = try gitPull(&buf, "/repo");
    try std.testing.expectEqualStrings("git -C /repo pull", s0);
    const s1 = try gitDiff(&buf, "/repo");
    try std.testing.expectEqualStrings("git -C /repo diff --exit-code", s1);
    const s2 = try gitStatus(&buf, "/repo");
    try std.testing.expectEqualStrings("git -C /repo status --porcelain", s2);
    const s3 = try gitAdd(&buf, "/repo");
    try std.testing.expectEqualStrings("git -C /repo add .", s3);
    const s4 = try nixUpdate(&buf, "/repo");
    try std.testing.expectEqualStrings("nix flake update --flake /repo", s4);
    const s5 = try nixRebuild(&buf, "/repo", "host");
    try std.testing.expectEqualStrings(
        "sudo nixos-rebuild switch --flake /repo#host --show-trace",
        s5,
    );
    const s6 = try nixKeep(&buf, 5);
    try std.testing.expectEqualStrings(
        "sudo nix-env --profile /nix/var/nix/profiles/system" ++ " --delete-generations +5",
        s6,
    );
}
