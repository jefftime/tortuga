const std = @import("std");
const Window = @import("window.zig").Window;
const Render = @import("render/render.zig").Render;
const RenderInstance = Render.RenderInstance;
const mem = @import("mem.zig");
const alloc = mem.alloc;
const dealloc = mem.dealloc;

pub fn main() anyerror!void {
    var window = try Window.init("Tortuga", 640, 480);
    defer window.deinit();

    var instance = try RenderInstance.init(&window);
    defer instance.deinit();

    while (true) {
        if (window.should_close()) break;
        window.update();
    }
}
