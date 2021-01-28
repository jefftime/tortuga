const std = @import("std");
const Window = @import("window").Window;
const Render = @import("render").Render;
const Context = Render.Context;
const Device = Render.Device;
const mem = @import("mem");
const alloc = mem.alloc;
const dealloc = mem.dealloc;

pub fn main() anyerror!void {
    // TODO: parse args

    var window = try Window.init("Tortuga", 640, 480);
    defer window.deinit();

    var context = try Context.init(&window, null);
    defer context.deinit();

    var sorted_devices = try alloc(u32, context.devices.len);
    defer dealloc(sorted_devices.ptr);

    // For now, just select the first device
    var device = try Device.init(&context, 0);
    defer device.deinit();

    while (true) {
        if (window.should_close()) break;
        window.update();
    }
}
