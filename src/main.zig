const std = @import("std");
const Window = @import("window.zig").Window;
const Render = @import("render/render.zig").Render;
const Context = Render.Context;
const Device = Render.Device;
const mem = @import("mem.zig");
const alloc_slice = mem.alloc_slice;
const dealloc = mem.dealloc;

pub fn main() anyerror!void {
    var window = try Window.init("Tortuga", 640, 480);
    defer window.deinit();

    var context = try Context.init(&window, null);
    defer context.deinit();

    var sorted_devices = try alloc_slice(u32, context.devices.len);
    defer dealloc(sorted_devices.ptr);

    // var device = try RenderDevice.init(&RenderContext, );
    // defer device.deinit();

    while (true) {
        if (window.should_close()) break;
        window.update();
    }
}
