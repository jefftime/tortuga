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

    var window: Window = undefined;
    try window.init("Tortuga", 960, 720);
    defer window.deinit();

    window.show_cursor();

    while (true) {
        if (window.should_close()) break;
        window.update();
    }
}
