const std = @import("std");
const Window = @import("window").Window;
const Render = @import("render").Render;
const Context = Render.Context;
const DeviceBuilder = Render.DeviceBuilder;
const Device = Render.Device;
const PassBuilder = Render.PassBuilder;
const Pass = Render.Pass;
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
    var device_builder = DeviceBuilder.init(&context);
    device_builder.with_device(0);
    device_builder.with_memory(2 * 1024 * 1024); // 2 MB of video memory
    var device = try device_builder.create();
    defer device.deinit();

    var pass_builder = PassBuilder.init(&device);
    pass_builder.add_stage();
    var pass = try pass_builder.create();
    defer pass.deinit();

    while (true) {
        if (window.should_close()) break;
        window.update();
    }
}
