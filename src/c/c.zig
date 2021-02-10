pub const builtin = @import("builtin");
pub const std = @import("std");

pub const c = @cImport({
    // libc
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("errno.h");
    @cInclude("string.h");

    // XCB
    @cInclude("xcb/xcb.h");

    // Vulkan
    @cDefine("VK_NO_PROTOTYPES", {});
    @cInclude("vulkan/vulkan_core.h");
    @cInclude("vulkan/vk_platform.h");

    // System specific
    if (builtin.os.tag == .linux) {
        @cInclude("vulkan/vulkan_xcb.h");
        @cInclude("dlfcn.h");
    }
});
