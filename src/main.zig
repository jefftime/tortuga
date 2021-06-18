const std = @import("std");

usingnamespace @import("util.zig");
usingnamespace @import("window.zig");
usingnamespace @import("render.zig");
usingnamespace @import("math.zig");
usingnamespace @import("mem.zig");
usingnamespace @import("c.zig");

const backend = @import("build_options").render_backend;

fn wgpu_log(
    level: c.WGPULogLevel,
    msg: [*c]const u8
) callconv(.C) void {
    std.log.warn("{s}", .{msg});
}

pub fn main() anyerror!void {
    // TODO: parse args

    const width = 960;
    const height = 720;

    var window: Window = undefined;
    try window.init("Tortuga", width, height);
    defer window.deinit();

    window.show_cursor();

    var device: Device = undefined;
    try device.init(&window);

    while (true) {
        if (window.should_close()) break;

        window.update();
    }
}
