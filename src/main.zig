const std = @import("std");

usingnamespace @import("util.zig");
usingnamespace @import("window.zig");
usingnamespace @import("render.zig");
usingnamespace @import("math.zig");
usingnamespace @import("mem.zig");
usingnamespace @import("c.zig");

const backend = @import("build_options").render_backend;

pub fn main() anyerror!void {
    // TODO: parse args

    const width = 960;
    const height = 720;

    var window: Window = undefined;
    try window.init("Tortuga", width, height);
    defer window.deinit();

    window.show_cursor();

    var renderer: GlRenderer = undefined;
    try renderer.init(&window);
    defer renderer.deinit();

    const vert = try read_file("./shaders/gl/gl.vert");
    const frag = try read_file("./shaders/gl/gl.frag");
    try renderer.compile_shader(vert, frag, null);
    renderer.load_vertices(&[_]f32 {
        0, 1, 1,
        -1, 0, 0,
        1, 0, 1
    });

    while (true) {
        if (window.should_close()) break;

        window.update();
        renderer.draw();
        renderer.swap_buffers() catch |_| {
            std.log.err("error swapping buffers", .{});
        };
    }
}
