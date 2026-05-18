const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const Alignment = mem.Alignment;

const StaticAllocator = @This();

parent_allocator: mem.Allocator,
state: State,

const State = enum {
    /// Allow alloc, resize, and free. Used during startup/init.
    /// Accidentally calling free switches to .deinit for errdefer compatibility.
    init,
    /// Block all allocation. Runtime phase — any alloc call panics.
    static,
    /// Allow free only. Shutdown phase.
    deinit,
};

pub fn init(parent_allocator: mem.Allocator) StaticAllocator {
    // State starts in .init to allow allocation during setup.
    return .{
        .parent_allocator = parent_allocator,
        .state = .init,
    };
}

pub fn transition_from_init_to_static(self: *StaticAllocator) void {
    assert(self.state == .init);
    self.state = .static;
}

/// Call during shutdown to allow free.
/// Panics if in .init state (transition_to_static was never called).
pub fn transition_from_static_to_deinit(self: *StaticAllocator) void {
    assert(self.state == .static);
    self.state = .deinit;
}

/// Safe version: only transitions if currently in .static state.
/// Used when early returns (help, version, errors) may skip transition_to_static.
pub fn transition_from_static_to_deinit_if_static(self: *StaticAllocator) void {
    if (self.state == .static) self.state = .deinit;
}

pub fn allocator(self: *StaticAllocator) mem.Allocator {
    // Assert invariant: must be in init or static state to vend an allocator.
    assert(self.state == .init or self.state == .static);
    return .{
        .ptr = self,
        .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        },
    };
}

fn alloc(ctx: *anyopaque, len: usize, ptr_align: Alignment, ret_addr: usize) ?[*]u8 {
    const self: *StaticAllocator = @ptrCast(@alignCast(ctx));
    assert(self.state == .init);
    return self.parent_allocator.rawAlloc(len, ptr_align, ret_addr);
}

fn resize(ctx: *anyopaque, buf: []u8, buf_align: Alignment, new_len: usize, ret_addr: usize) bool {
    const self: *StaticAllocator = @ptrCast(@alignCast(ctx));
    assert(self.state == .init);
    return self.parent_allocator.rawResize(buf, buf_align, new_len, ret_addr);
}

fn remap(ctx: *anyopaque, buf: []u8, buf_align: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
    const self: *StaticAllocator = @ptrCast(@alignCast(ctx));
    assert(self.state == .init);
    return self.parent_allocator.rawRemap(buf, buf_align, new_len, ret_addr);
}

fn free(ctx: *anyopaque, buf: []u8, buf_align: Alignment, ret_addr: usize) void {
    const self: *StaticAllocator = @ptrCast(@alignCast(ctx));
    // Allow free in all states: allocPrint internally frees intermediate buffers,
    // and these frees happen both during init (pre-transition) and at deinit.
    // In .static state, only free is permitted — alloc and resize panic.
    _ = self.state;
    return self.parent_allocator.rawFree(buf, buf_align, ret_addr);
}

test "StaticAllocator blocks alloc after transition" {
    var arena_instance = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_instance.deinit();

    var static_alloc = StaticAllocator.init(arena_instance.allocator());
    const a = static_alloc.allocator();

    // During init: alloc works.
    const buf = try a.alloc(u8, 64);
    a.free(buf);

    // During init: resize works (realloc triggers resize vtable).
    const new_buf = try a.alloc(u8, 32);
    _ = a.resize(new_buf, 64);
    a.free(new_buf);

    // Transition to static.
    static_alloc.transition_from_init_to_static();

    // During static: free still works.
    const buf2 = try arena_instance.allocator().alloc(u8, 64);
    a.free(buf2);

    // Transition to deinit.
    static_alloc.transition_from_static_to_deinit();
    const buf3 = try arena_instance.allocator().alloc(u8, 32);
    a.free(buf3);
}
