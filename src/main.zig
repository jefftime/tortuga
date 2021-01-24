const std = @import("std");
const Window = @import("window.zig").Window;

pub fn main() anyerror!void {
    var window = try Window.init("Zortuga", 640, 480);
    defer window.deinit();

    while (true) {
        if (window.should_close()) break;
        window.update();
    }
}
