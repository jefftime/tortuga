const render_backend = @import("build_options").render_backend;
const builtin = @import("std").builtin;

pub const c = @cImport({
    // libc
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("errno.h");
    @cInclude("string.h");

    // XCB
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/xfixes.h");
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xlib-xcb.h");

    if (render_backend == .vulkan) {
        // Vulkan
        @cDefine("VK_NO_PROTOTYPES", {});
        @cInclude("vulkan/vulkan_core.h");
        @cInclude("vulkan/vk_platform.h");

        // System specific
        if (builtin.os.tag == .linux) {
            @cInclude("vulkan/vulkan_xcb.h");
            @cInclude("dlfcn.h");
        }
    }

    if (render_backend == .webgpu) {
        @cInclude("webgpu-headers/webgpu.h");
        @cInclude("wgpu.h");
    }

    if (render_backend == .gl) {
        @cInclude("glad/glad.h");
        @cInclude("glad/glad_egl.h");
        @cInclude("glad/eglplatform.h");
        @cInclude("GL/gl.h");
    }

});
