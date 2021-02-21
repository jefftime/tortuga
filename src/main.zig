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
    var data: Uniforms = Uniforms {
        .colors = [4]Vec3 {
            Vec3 { .x = 1, .y = 0, .z = 0 },
            Vec3 { .x = 0, .y = 0, .z = 1 },
            Vec3 { .x = 0, .y = 1, .z = 0 },
            Vec3 { .x = 1, .y = 1, .z = 1 }
        }
    };
    try shader.write_uniforms(Uniforms, &data);

    var vertices: Buffer = undefined;
    var indices: Buffer = undefined;
    try create_vertex_data(&device, &vertices, &indices);
    defer vertices.deinit();
    defer indices.deinit();

    var pass: Pass = undefined;
    try device.create_pass(&shader, &pass);
    defer pass.deinit();
    try pass.write_command_buffers(&vertices, &indices);

    while (true) {
        if (window.should_close()) break;
        window.update();

        const token = pass.begin() orelse break;
        pass.submit(token);
    }
}

fn create_vertex_data(
    device: *Device,
    out_verts: *Buffer,
    out_indices: *Buffer
) !void {
    const vertex_data = [_]f32 {
        -0.5, -0.5, 0.0, 0,
        -0.5, 0.5, 0.0, 1,
        0.5, 0.5, 0.0, 2,
        0.5, -0.5, 0.0, 3
    };
    const index_data = [_]u16 { 0, 1, 2, 2, 3, 0 };

    out_verts.* = try device.memory.create_buffer(
        16,
        MemoryUsage.Vertex.value(),
        vertex_data.len * @sizeOf(f32)
    );
    out_indices.* = try device.memory.create_buffer(
        16,
        MemoryUsage.Index.value(),
        index_data.len * @sizeOf(u16)
    );

    try out_verts.write(f32, &vertex_data);
    try out_indices.write(u16, &index_data);
}
