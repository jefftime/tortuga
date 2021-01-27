const std = @import("std");
const c = @import("c.zig").c;

pub fn alloc(comptime T: type, len: usize) ![*]T {
    var mem: *T = undefined;
    var alignment: usize = switch (@alignOf(T)) {
        0, 1, 2, 3, 4, 5, 6, 7 => 8,
        else => @alignOf(T)
    };
    std.log.info("alignment: {}", .{alignment});

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

pub fn dealloc(ptr: anytype) void { c.free(ptr); }
