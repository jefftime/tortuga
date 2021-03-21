const std = @import("std");

usingnamespace @import("util");
usingnamespace @import("window");
usingnamespace @import("render");
usingnamespace @import("math");
usingnamespace @import("mem");

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

    var memory: MemoryService = undefined;
    try memory.init(&device, 2 * 1024 * 1024);
    defer memory.deinit();

    const vsrc = try read_file("shaders/vert.spv");
    defer dealloc(vsrc.ptr);
    const fsrc = try read_file("shaders/frag.spv");
    defer dealloc(fsrc.ptr);
    var shader: ShaderGroup = undefined;
    try device.create_shader(
        &memory.memory,
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

    try memory.map();

    var mesh: Mesh = undefined;
    try mesh.init(&memory.memory, &vertices, &indices);
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

    // var texture_data: []u8 = &[_]u8 { 0 };
    // var texture: Buffer = undefined;
    // try device.memory.create_buffer(texture);
    // try texture.stage(texture_data);
    // try pass.transfer(texture);

    memory.unmap();
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
