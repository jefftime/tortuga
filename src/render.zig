const render_backend = @import("build_options").render_backend;

const subfolder = switch (render_backend) {
    .webgpu => "webgpu",
    .vulkan => "vulkan"
};

pub usingnamespace @import("render/" ++ subfolder ++ ".zig");
