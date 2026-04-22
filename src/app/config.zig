pub const Config = struct {
    repo: []const u8,
    hostname: []const u8,
    keep: u8,
    update: bool,
    diff: bool,
    tui: bool = false,
};
