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
pub var vkDestroyInstance: c.PFN_vkDestroyInstance = undefined;
pub var vkCreateXcbSurfaceKHR: c.PFN_vkCreateXcbSurfaceKHR = undefined;
pub var vkDestroySurfaceKHR: c.PFN_vkDestroySurfaceKHR = undefined;
pub var vkEnumeratePhysicalDevices: c.PFN_vkEnumeratePhysicalDevices = undefined;
pub var vkGetDeviceProcAddr: c.PFN_vkGetDeviceProcAddr = undefined;
pub var vkCreateDevice: c.PFN_vkCreateDevice = undefined;
pub var vkDestroyDevice: c.PFN_vkDestroyDevice = undefined;
pub var vkGetPhysicalDeviceQueueFamilyProperties:
    c.PFN_vkGetPhysicalDeviceQueueFamilyProperties = undefined;
pub var vkGetPhysicalDeviceSurfaceSupportKHR:
    c.PFN_vkGetPhysicalDeviceSurfaceSupportKHR = undefined;
pub var vkGetPhysicalDeviceSurfaceCapabilitiesKHR:
    c.PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR = undefined;
pub var vkGetPhysicalDeviceSurfaceFormatsKHR:
    c.PFN_vkGetPhysicalDeviceSurfaceFormatsKHR = undefined;
pub var vkGetPhysicalDeviceSurfacePresentModesKHR:
    c.PFN_vkGetPhysicalDeviceSurfacePresentModesKHR = undefined;
pub var vkCreateSwapchainKHR: c.PFN_vkCreateSwapchainKHR = undefined;
pub var vkDestroySwapchainKHR: c.PFN_vkDestroySwapchainKHR = undefined;
pub var vkGetSwapchainImagesKHR: c.PFN_vkGetSwapchainImagesKHR = undefined;
pub var vkGetPhysicalDeviceMemoryProperties:
    c.PFN_vkGetPhysicalDeviceMemoryProperties = undefined;
pub var vkGetPhysicalDeviceProperties:
    c.PFN_vkGetPhysicalDeviceProperties = undefined;
pub var vkGetPhysicalDeviceFeatures:
    c.PFN_vkGetPhysicalDeviceFeatures = undefined;

pub const Context = struct {
    window: *const Window,
    vk_handle: ?*const c_void,
    instance: c.VkInstance,
    surface: c.VkSurfaceKHR,
    devices: []c.VkPhysicalDevice,

    pub fn init(window: *const Window, libpath: ?[]const u8) !Context {
        const extensions = [_][*c]const u8 {
            c.VK_KHR_SURFACE_EXTENSION_NAME,
            c.VK_KHR_XCB_SURFACE_EXTENSION_NAME
        };

        const vk_handle = try load_vulkan(libpath);
        try load_preinstance_functions();
        const supported_exts = try get_extensions();
        defer dealloc(supported_exts.ptr);

        // Check extensions
        var xcb_ext = false;
        var surface_ext = false;
        for (supported_exts) |ext| {
            std.log.info("found supported extension {}", .{ext});

            if (c.strcmp(&ext.extensionName, "VK_KHR_surface") != 0) {
                surface_ext = true;
            }
            if (c.strcmp(&ext.extensionName, "VK_KHR_xcb_surface") != 0) {
                xcb_ext = true;
            }
        }
        if (!(xcb_ext and surface_ext)) {
            std.log.err(
                "device does not support VK_KHR_surface or VK_KHR_xcb_surface",
                .{}
            );
            return error.UnsupportedExtensions;
        }

        const instance = try create_instance(
            "",
            "",
            extensions[0..extensions.len]
        );
        try load_instance_functions(instance);
        errdefer vkDestroyInstance.?(instance, null);

        const surface = try create_surface(&instance, window);
        errdefer vkDestroySurfaceKHR.?(instance, surface, null);

        const physical_devices = try get_devices(&instance);
        for (physical_devices) |device| {
            var properties: c.VkPhysicalDeviceProperties = undefined;
            vkGetPhysicalDeviceProperties.?(device, &properties);
            std.log.info("found physical device `{}`", .{properties.deviceName});
        }

        return Context {
            .window = window,
            .vk_handle = null,
            .instance = instance,
            .surface = surface,
            .devices = physical_devices
        };
    }

    pub fn deinit(self: *Context) void {
        std.log.info("destroy Context", .{});
        dealloc(self.devices.ptr);
        vkDestroySurfaceKHR.?(self.instance, self.surface, null);
        vkDestroyInstance.?(self.instance, null);
    }
};

fn load_vulkan(libpath: ?[]const u8) !*const c_void {
    const path: []const u8 = libpath orelse if (builtin.os.tag == .linux) path: {
        break :path "libvulkan.so";
    } else {
        return error.Unimplemented;
    };

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

fn load(prefix: ?c.VkInstance, comptime symbol: []const u8) !void {
    std.log.info("loading symbol `{}`", .{symbol});
    const result = if (prefix) |p| a: {
        break :a get_proc.?(p, symbol.ptr)
            orelse return error.BadFunctionLoad;
    } else a: {
        break :a get_proc.?(null, symbol.ptr)
            orelse return error.BadFunctionLoad;
    };

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

    std.log.info("created VkInstance", .{});

    return instance;
}

fn load_instance_functions(instance: ?c.VkInstance) !void {
    try load(instance, "vkDestroyInstance");
    try load(instance, "vkEnumerateInstanceExtensionProperties");
    try load(instance, "vkCreateXcbSurfaceKHR");
    try load(instance, "vkDestroySurfaceKHR");
    try load(instance, "vkEnumeratePhysicalDevices");
    try load(instance, "vkGetDeviceProcAddr");
    try load(instance, "vkCreateDevice");
    try load(instance, "vkDestroyDevice");
    try load(instance, "vkGetPhysicalDeviceQueueFamilyProperties");
    try load(instance, "vkGetPhysicalDeviceSurfaceSupportKHR");
    try load(instance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR");
    try load(instance, "vkGetPhysicalDeviceSurfaceFormatsKHR");
    try load(instance, "vkGetPhysicalDeviceSurfacePresentModesKHR");
    try load(instance, "vkCreateSwapchainKHR");
    try load(instance, "vkDestroySwapchainKHR");
    try load(instance, "vkGetSwapchainImagesKHR");
    try load(instance, "vkGetPhysicalDeviceMemoryProperties");
    try load(instance, "vkGetPhysicalDeviceProperties");
    try load(instance, "vkGetPhysicalDeviceFeatures");
}

fn create_surface(
    instance: *const c.VkInstance,
    window: *const Window
) !c.VkSurfaceKHR {
    const create_info = if (builtin.os.tag == .linux) info: {
        break :info c.VkXcbSurfaceCreateInfoKHR {
            .sType =
                c.VkStructureType.VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR,
            .pNext = null,
            .flags = 0,
            .connection = window.*.cn,
            .window = window.*.wn
        };
    } else {
        return error.Unimplemented;
    };

    var surface: c.VkSurfaceKHR = undefined;
    const result = vkCreateXcbSurfaceKHR.?(
        instance.*,
        &create_info,
        null,
        &surface
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadSurface;

    std.log.info("created VkSurfaceKHR", .{});

    return surface;
}

fn get_devices(instance: *const c.VkInstance) ![]c.VkPhysicalDevice {
    var n_devices: u32 = undefined;
    var result = vkEnumeratePhysicalDevices.?(instance.*, &n_devices, null);
    if (result != c.VkResult.VK_SUCCESS) return error.BadDevices;
    if (n_devices == 0) {
        std.log.err("could not find any physical devices", .{});
        return error.NoDevices;
    } else {
        std.log.info("found {} physical devices", .{n_devices});
    }

    var pdevices = try alloc(c.VkPhysicalDevice, n_devices);
    errdefer dealloc(pdevices);

    result = vkEnumeratePhysicalDevices.?(instance.*, &n_devices, pdevices);
    if (result != c.VkResult.VK_SUCCESS) return error.BadDevices;

    return pdevices[0..n_devices];
}
