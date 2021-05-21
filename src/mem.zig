const std = @import("std");
usingnamespace @import("c.zig");

fn alloc_internal(comptime T: type, len: usize) ![*]T {
    var mem: *T = undefined;
    var alignment: usize = switch (@alignOf(T)) {
        0, 1, 2, 3, 4, 5, 6, 7 => 8,
        else => @alignOf(T)
    };

    const rc = c.posix_memalign(
        @ptrCast([*c]?*c_void, &mem),
        alignment,
        len * @sizeOf(T)
    );
    switch (rc) {
        c.EINVAL => return error.BadAlignment,
        c.ENOMEM => return error.OutOfMemory,
        else => {}
    }

    return @ptrCast([*]T, mem);
}

pub fn alloc(comptime T: type, len: usize) ![]T {
    const result = try alloc_internal(T, len);
    return result[0..len];
}

pub fn alloc_zeroed(comptime T: type, len: usize) ![]T {
    const result = try alloc(T, len);
    @memset(@ptrCast([*]u8, result.ptr), 0, @sizeOf(T) * len);
    return result;
}

pub fn new(comptime T: type) !*T {
    return @ptrCast(*T, try alloc_internal(T, 1));
}

pub fn dealloc(ptr: anytype) void { c.free(@ptrCast(*c_void, ptr)); }
