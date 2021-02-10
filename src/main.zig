const std = @import("std");
const read_file = @import("util").read_file;
const Window = @import("window").Window;
const Render = @import("render").Render;
const Context = Render.Context;
const DeviceBuilder = Render.DeviceBuilder;
const Device = Render.Device;
const PassBuilder = Render.PassBuilder;
const Binding = Render.Binding;
const Pass = Render.Pass;
const mem = @import("mem");
const alloc = mem.alloc;
const dealloc = mem.dealloc;

fn create_render_pass(pass: *Pass, device: *Device) !void {
    var pass_builder = PassBuilder.init(device);

    const vsrc = try read_file("shaders/vert.spv");
    defer dealloc(vsrc.ptr);
    const fsrc = try read_file("shaders/frag.spv");
    defer dealloc(fsrc.ptr);

    const vshader = try device.create_shader(&[_]Binding {.Vec3, .Vec3}, vsrc);
    const fshader = try device.create_shader(null, fsrc);

    try pass_builder.create(pass, vshader, fshader);
}

pub fn main() anyerror!void {
    // TODO: parse args

    var window = try Window.init("Tortuga", 640, 480);
    defer window.deinit();

    var context = try Context.init(&window, null);
    defer context.deinit();

    var sorted_devices = try alloc(u32, context.devices.len);
    defer dealloc(sorted_devices.ptr);

    // TODO: Properly select GPU device
    var device_builder = DeviceBuilder.init(&context);
    device_builder.with_device(0);
    device_builder.with_memory(2 * 1024 * 1024); // 2 MB of video memory
    var device: Device = undefined;
    try device_builder.create(&device);
    defer device.deinit();

    var pass: Pass = undefined;
    try create_render_pass(&pass, &device);
    defer pass.deinit();

    while (true) {
        if (window.should_close()) break;
        window.update();
    }
}
