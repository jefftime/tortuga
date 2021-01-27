const std = @import("std");
const mem_zig = @import("../mem.zig");
const alloc = mem_zig.alloc;
const dealloc = mem_zig.dealloc;
const builtin = @import("builtin");
const c = @import("../c.zig").c;
const Window = @import("../window.zig").Window;

pub var get_proc: c.PFN_vkGetInstanceProcAddr = undefined;
pub var vkCreateInstance: c.PFN_vkCreateInstance = undefined;
pub var vkEnumerateInstanceExtensionProperties:
    c.PFN_vkEnumerateInstanceExtensionProperties = undefined;

pub const RenderInstance = struct {

    window: *Window,
    vk_handle: ?*const c_void,
    instance: c.VkInstance,
    // surface: c.VkSurfaceKHR,
    // pdevices: [*]c.VkPhysicalDevice,

    pub fn init(window: *Window) !RenderInstance {
        const extensions = [_][*c]const u8 {
            c.VK_KHR_SURFACE_EXTENSION_NAME,
            c.VK_KHR_XCB_SURFACE_EXTENSION_NAME
        };

        // TODO: Allow override of vulkan libpath
        const vk_handle = try load_vulkan(null);
        try load_preinstance_functions();
        const supported_exts = try get_extensions();
        // std.log.info("supported extensions:", .{});
        // for (supported_exts) |ext| {
        //     std.log.info("{}", .{ext});
        // }
        const instance = try create_instance(
            "",
            "",
            extensions[0..extensions.len]
        );

        return RenderInstance {
            .window = window,
            .vk_handle = null,
            .instance = instance
        };
    }

    pub fn deinit(self: *RenderInstance) void {
    }
};

fn load_vulkan(libpath: ?[]const u8) !*const c_void {
    const path: []const u8 = libpath orelse "libvulkan.so";

    const vk_handle = if (builtin.os.tag == .linux) handle: {
        const handle = c.dlopen(@ptrCast([*c]const u8, path), c.RTLD_NOW) orelse {
            std.log.err("could not open libpath: {}", .{libpath});
            return error.BadPath;
        };

        break :handle handle;
    } else {
        return error.NotImplemented;
    };

    get_proc = @ptrCast(
        c.PFN_vkGetInstanceProcAddr,
        c.dlsym(vk_handle, "vkGetInstanceProcAddr")
    ) orelse {
        std.log.err("could not load vkGetInstanceProcAddr", .{});
        return error.BadFunctionLoad;
    };

    return vk_handle;
}

fn load(prefix: ?*c.VkInstance, comptime symbol: []const u8) !void {
    std.log.info("loading symbol: {}", .{symbol});
    const result = get_proc.?(null, symbol.ptr)
        orelse return error.BadFunctionLoad;
    @field(@This(), symbol) = @ptrCast(@field(c, "PFN_" ++ symbol), result);
}

fn load_preinstance_functions() !void {
    try load(null, "vkCreateInstance");
    try load(null, "vkEnumerateInstanceExtensionProperties");
}

fn get_extensions() ![]c.VkExtensionProperties {
    var len: u32 = undefined;

    var result = vkEnumerateInstanceExtensionProperties.?(null, &len, null);
    if (result != c.VkResult.VK_SUCCESS) {
        return error.BadExtensions;
    }

    var exts = try alloc(c.VkExtensionProperties, len);
    result = vkEnumerateInstanceExtensionProperties.?(null, &len, exts);
    if (result != c.VkResult.VK_SUCCESS) {
        return error.BadInstanceExtensions;
    }

    return exts[0..len];
}

fn create_instance(
    app_name: [*c]const u8,
    engine_name: [*c]const u8,
    exts: []const [*c]const u8
) !c.VkInstance {
    const layers = [_][]const u8 {
        "VK_LAYER_LUNARG_standard_validation"
    };

    const app_info = c.VkApplicationInfo {
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = app_name,
        .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = engine_name,
        .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = c.VK_API_VERSION_1_0,
    };
    const create_info = c.VkInstanceCreateInfo {
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = @intCast(u32, exts.len),
        .ppEnabledExtensionNames = exts.ptr,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = c.VK_NULL_HANDLE,
    };

    var instance: c.VkInstance = undefined;
    const result = vkCreateInstance.?(&create_info, null, &instance);
    if (result != c.VkResult.VK_SUCCESS) {
        std.log.err("could not create VkInstance", .{});
        return error.BadInstance;
    }

    std.log.info("created VkInstance!", .{});

    return instance;
}

fn load_instance_functions(instance: *VkInstance) !void {
    
}
