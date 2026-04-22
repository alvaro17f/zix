const std = @import("std");
const builtin = @import("builtin");

const Self = @This();

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
pub const allocator = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.c_allocator;

pub fn detectLeaks() usize {
    if (builtin.mode == .Debug) {
        return debug_allocator.detectLeaks();
    }
    return 0;
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

test "FixedBuffer alloc/free" {
    var buf: [256]u8 = undefined;
    var fb = FixedBuffer.init(&buf);
    const alloc = fb.allocator();
    const ptr = try alloc.alloc(u8, 16);
    try std.testing.expectEqual(@as(usize, 16), ptr.len);
    alloc.free(ptr);
}

test "Arena roundtrip and withArena" {
    var arena = Arena.init();
    defer arena.deinit();
    const alloc = arena.allocator();
    const ptr = try alloc.alloc(u8, 8);
    try std.testing.expectEqual(@as(usize, 8), ptr.len);
}

test "withArena works" {
    try withArena(struct {
        fn f(a: std.mem.Allocator) !void {
            const ptr = try a.alloc(u8, 4);
            a.free(ptr);
        }
    }.f);
}

test "detectLeaks returns 0 in release" {
    if (builtin.mode == .Debug) return error.SkipZigTest;
    try std.testing.expectEqual(@as(usize, 0), detectLeaks());
}
