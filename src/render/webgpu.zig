pub usingnamespace @import("webgpu/device.zig");

usingnamespace @import("../window.zig");

pub fn init_context(out_context: *Context) !void {
}

pub const Context = struct {
    pub fn init(self: *Context, window: *Window, libpath: ?[]const u8) !void {}

    pub fn deinit(self: *Context) void {}

    pub fn create_device(
        self: *Context,
        index: u32,
        size: usize,
        out_device: *Device
    ) !void {}
};

pub const MemoryService = struct {
    pub fn init(self: *MemoryService, device: *Device) !void {}

    pub fn deinit(self: *MemoryService) void {}
};
