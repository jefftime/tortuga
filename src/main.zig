const std = @import("std");
const read_file = @import("util").read_file;
const Window = @import("window").Window;
const Render = @import("render").Render;
const Context = Render.Context;
const DeviceBuilder = Render.DeviceBuilder;
const Device = Render.Device;
const Binding = Render.Binding;
const ShaderGroup = Render.ShaderGroup;
const Pass = Render.Pass;
const mem = @import("mem");
const alloc = mem.alloc;
const dealloc = mem.dealloc;
const geometry = @import("math").geometry;
const Vec3 = geometry.Vec3;
const Vec4 = geometry.Vec4;
const Mat4 = geometry.Mat4;

const Uniforms = extern struct {
    color: Vec3,
    m: Mat4,
};

pub fn main() anyerror!void {
    // TODO: parse args

    var window: Window = undefined;
    try window.init("Tortuga", 960, 720);
    defer window.deinit();

    var context: Context = undefined;
    try context.init(&window, null);
    defer context.deinit();

    // TODO: Properly select GPU device
    var device: Device = undefined;
    try context.create_device(0, 2 * 1024 * 1024, &device);
    defer device.deinit();

    const vsrc = try read_file("shaders/vert.spv");
    defer dealloc(vsrc.ptr);
    const fsrc = try read_file("shaders/frag.spv");
    defer dealloc(fsrc.ptr);
    var shader: ShaderGroup = undefined;
    try device.create_shader(
        &device.memory,
        Uniforms,
        &[_][]const Binding { &[_] Binding { .Vec3, .Vec3 } },
        vsrc,
        fsrc,
        &shader
    );
    defer shader.deinit();
    const data: Uniforms = Uniforms {
        .m = Mat4 {
            .data = [_]f32 {
                0, 1, 1, 0,
                0, 0, 0, 0,
                0, 0, 0, 0,
                0, 0, 0, 0
            }
        },
        .color = Vec3 { .x = 1, .y = 1, .z = 0 },
    };
    try shader.write_uniforms(Uniforms, &data);

    var pass: Pass = undefined;
    try device.create_pass(&shader, &pass);
    defer pass.deinit();
    try pass.write_command_buffers();

    while (true) {
        if (window.should_close()) break;
        window.update();
        pass.update();
    }
}
