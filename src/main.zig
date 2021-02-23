const std = @import("std");
const read_file = @import("util").read_file;
const Window = @import("window").Window;
const Render = @import("render").Render;
const Context = Render.Context;
const DeviceBuilder = Render.DeviceBuilder;
const Device = Render.Device;
const Buffer = Render.Buffer;
const Binding = Render.Binding;
const ShaderGroup = Render.ShaderGroup;
const MemoryUsage = Render.MemoryUsage;
const Pass = Render.Pass;
const Mesh = Render.Mesh;
const mem = @import("mem");
const alloc = mem.alloc;
const dealloc = mem.dealloc;
const geometry = @import("math").geometry;
const Vec3 = geometry.Vec3;
const Vec4 = geometry.Vec4;
const Mat4 = geometry.Mat4;

const Uniforms = extern struct {
    colors: [4]Vec3
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
        &[_][]const Binding { &[_] Binding { .Vec3, .Float32 } },
        vsrc,
        fsrc,
        &shader
    );
    defer shader.deinit();

    var pass: Pass = undefined;
    try device.create_pass(&shader, &pass);
    defer pass.deinit();

    const vertices = [_]f32 {
        -0.5, -0.5, 0.0, 0,
        -0.5, 0.5, 0.0, 1,
        0.5, 0.5, 0.0, 2,
        0.5, -0.5, 0.0, 3
    };
    const indices = [_]u16 { 0, 1, 2, 2, 3, 0 };

    try device.memory.map();

    var mesh: Mesh = undefined;
    try mesh.init(&device, &vertices, &indices);
    defer mesh.deinit();

    var data: Uniforms = Uniforms {
        .colors = [4]Vec3 {
            Vec3 { .x = 1, .y = 0, .z = 0 },
            Vec3 { .x = 0, .y = 0, .z = 1 },
            Vec3 { .x = 0, .y = 1, .z = 0 },
            Vec3 { .x = 1, .y = 1, .z = 1 }
        }
    };
    try pass.set_uniforms(Uniforms, &data);

    device.memory.unmap();

    window.show_cursor();

    while (true) {
        if (window.should_close()) break;
        window.update();

        const token = pass.begin() catch |err| {
            switch (err) {
                error.OutOfDatePass => continue,
                else => return err
            }
        };

        try pass.draw(token, &mesh);

        pass.submit(token) catch |err| {
            switch (err) {
                error.OutOfDatePass => continue,
                else => return err
            }
        };
    }
}
