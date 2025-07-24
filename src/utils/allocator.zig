const std = @import("std");
const builtin = @import("builtin");

const Self = @This();

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
pub const allocator = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.c_allocator;

pub fn detectLeaks() bool {
    if (builtin.mode == .Debug) {
        return debug_allocator.detectLeaks();
    }
    return false;
}

pub const FixedBuffer = struct {
    buffer: []u8,
    fba: std.heap.FixedBufferAllocator,

    pub fn init(buffer: []u8) FixedBuffer {
        return .{
            .buffer = buffer,
            .fba = std.heap.FixedBufferAllocator.init(buffer),
        };
    }

    pub fn allocator(self: *FixedBuffer) std.mem.Allocator {
        return self.fba.allocator();
    }
};

pub const Arena = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init() Arena {
        return .{ .arena = std.heap.ArenaAllocator.init(Self.allocator) };
    }

    pub fn deinit(self: *Arena) void {
        self.arena.deinit();
    }

    pub fn allocator(self: *Arena) std.mem.Allocator {
        return self.arena.allocator();
    }
};

pub fn withArena(comptime body: fn (std.mem.Allocator) anyerror!void) !void {
    var arena = Arena.init();
    defer arena.deinit();
    try body(arena.allocator());
}
