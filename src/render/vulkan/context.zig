const std = @import("std");
const builtin = std.builtin;

usingnamespace @import("../../mem.zig");
usingnamespace @import("../../c.zig");
usingnamespace @import("../../window.zig");
usingnamespace @import("device.zig");

pub const Context = struct {
    pub var get_proc: c.PFN_vkGetInstanceProcAddr = undefined;
    pub var vkCreateInstance: c.PFN_vkCreateInstance = undefined;
    pub var vkEnumerateInstanceExtensionProperties:
        c.PFN_vkEnumerateInstanceExtensionProperties = undefined;
    pub var vkEnumerateInstanceLayerProperties:
        c.PFN_vkEnumerateInstanceLayerProperties = undefined;
    pub var vkDestroyInstance: c.PFN_vkDestroyInstance = undefined;
    pub var vkCreateXcbSurfaceKHR: c.PFN_vkCreateXcbSurfaceKHR = undefined;
    pub var vkDestroySurfaceKHR: c.PFN_vkDestroySurfaceKHR = undefined;
    pub var vkEnumeratePhysicalDevices:
        c.PFN_vkEnumeratePhysicalDevices = undefined;
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

    window: *const Window,
    vk_handle: ?*const c_void,
    instance: c.VkInstance,
    surface: c.VkSurfaceKHR,
    devices: []c.VkPhysicalDevice, // TODO: Abstract this out

    pub fn init(
        out_context: *Context,
        window: *const Window,
        libpath: ?[]const u8,
    ) !void {
        const extensions = [_][*c]const u8 {
            c.VK_KHR_SURFACE_EXTENSION_NAME,
            c.VK_KHR_XCB_SURFACE_EXTENSION_NAME
        };

        const vk_handle = try load_vulkan(libpath);
        try load_preinstance_functions();

        // Check layers
        const supported_layers = try get_layers();
        defer dealloc(supported_layers.ptr);
        var standard_validation_layer = false;
        for (supported_layers) |layer| {
            std.log.info("found supported layer {s}", .{layer.layerName});
            const layer_match = c.strcmp(
                &layer.layerName,
                "VK_LAYER_LUNARG_standard_validation"
            );
            if (layer_match != 0) standard_validation_layer = true;
        }
        // TODO: remove this and don't hard error on unsupported validation
        // layers
        if (!standard_validation_layer) {
            return error.UnsupportedLayers;
        }
        var layers = [_][*c]const u8 {
            "VK_LAYER_LUNARG_standard_validation"
        };

        // Check extensions
        const supported_exts = try get_extensions();
        defer dealloc(supported_exts.ptr);
        var xcb_ext = false;
        var surface_ext = false;
        for (supported_exts) |ext| {
            std.log.info(
                "found supported extension {s}",
                .{ext.extensionName}
            );

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
            extensions[0..extensions.len],
            layers[0..layers.len]
        );
        try load_instance_functions(instance);
        errdefer vkDestroyInstance.?(instance, null);

        const surface = try create_surface(instance, window);
        errdefer vkDestroySurfaceKHR.?(instance, surface, null);

        const physical_devices = try get_devices(&instance);
        for (physical_devices) |device| {
            var properties: c.VkPhysicalDeviceProperties = undefined;
            vkGetPhysicalDeviceProperties.?(device, &properties);
            std.log.info(
                "found physical device `{s}`",
                .{properties.deviceName}
            );
        }

        out_context.* = Context {
            .window = window,
            .vk_handle = null,
            .instance = instance,
            .surface = surface,
            .devices = physical_devices
        };
    }

    pub fn deinit(self: *const Context) void {
        dealloc(self.devices.ptr);
        vkDestroySurfaceKHR.?(self.instance, self.surface, null);
        vkDestroyInstance.?(self.instance, null);
        std.log.info("destroying Context", .{});
    }

    pub fn create_device(
        self: *const Context,
        device_id: usize,
        mem_size: usize,
        out_device: *Device
    ) !void {
        try out_device.init(self, device_id, mem_size);
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
            std.log.err("could not open libpath: {s}", .{libpath});
            return error.BadPath;
        };

        break :handle handle;
    } else {
        return error.NotImplemented;
    };

    Context.get_proc = @ptrCast(
        c.PFN_vkGetInstanceProcAddr,
        c.dlsym(vk_handle, "vkGetInstanceProcAddr")
    ) orelse {
        std.log.err("could not load vkGetInstanceProcAddr", .{});
        return error.BadFunctionLoad;
    };

    return vk_handle;
}

fn load(prefix: ?c.VkInstance, comptime symbol: []const u8) !void {
    std.log.info("loading instance function `{s}`", .{symbol});
    const result = if (prefix) |p| a: {
        break :a Context.get_proc.?(p, symbol.ptr)
            orelse return error.BadFunctionLoad;
    } else a: {
        break :a Context.get_proc.?(null, symbol.ptr)
            orelse return error.BadFunctionLoad;
    };

    @field(Context, symbol) = @ptrCast(@field(c, "PFN_" ++ symbol), result);
}

fn load_preinstance_functions() !void {
    try load(null, "vkCreateInstance");
    try load(null, "vkEnumerateInstanceExtensionProperties");
    try load(null, "vkEnumerateInstanceLayerProperties");
}

fn get_extensions() ![]c.VkExtensionProperties {
    var len: u32 = 0;

    var result = Context.vkEnumerateInstanceExtensionProperties.?(
        null,
        &len,
        null
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadExtensions;

    var exts = try alloc(c.VkExtensionProperties, len);
    result = Context.vkEnumerateInstanceExtensionProperties.?(
        null,
        &len,
        exts.ptr
    );
    if (result != c.VkResult.VK_SUCCESS) {
        return error.BadInstanceExtensions;
    }

    return exts;
}

fn get_layers() ![]c.VkLayerProperties {
    var len: u32 = 0;
    var result = Context.vkEnumerateInstanceLayerProperties.?(
        &len,
        null
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadLayers;
    var layers = try alloc(c.VkLayerProperties, len);
    result = Context.vkEnumerateInstanceLayerProperties.?(
        &len,
        layers.ptr
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadLayers;

    return layers;
}

fn create_instance(
    app_name: [*c]const u8,
    engine_name: [*c]const u8,
    exts: []const [*c]const u8,
    layers: []const [*c]const u8
) !c.VkInstance {
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
        .enabledLayerCount = @intCast(u32, layers.len),
        .ppEnabledLayerNames = layers.ptr
    };

    var instance: c.VkInstance = undefined;
    const result = Context.vkCreateInstance.?(&create_info, null, &instance);
    if (result != c.VkResult.VK_SUCCESS) {
        std.log.err("could not create Vulkan instance", .{});
        return error.BadInstance;
    }

    std.log.info("created Vulkan instance", .{});

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
    instance: c.VkInstance,
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

    var surface: c.VkSurfaceKHR = null;
    const result = Context.vkCreateXcbSurfaceKHR.?(
        instance,
        &create_info,
        null,
        &surface
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadSurface;

    std.log.info("created Vulkan surface", .{});

    return surface;
}

fn get_devices(instance: *const c.VkInstance) ![]c.VkPhysicalDevice {
    var n_devices: u32 = undefined;
    var result = Context.vkEnumeratePhysicalDevices.?(
        instance.*,
        &n_devices,
        null
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadDevices;
    if (n_devices == 0) {
        std.log.err("could not find any physical devices", .{});
        return error.NoDevices;
    } else {
        std.log.info("found {} physical devices", .{n_devices});
    }

    var pdevices = try alloc(c.VkPhysicalDevice, n_devices);
    errdefer dealloc(pdevices.ptr);

    result = Context.vkEnumeratePhysicalDevices.?(
        instance.*,
        &n_devices,
        pdevices.ptr
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadDevices;

    return pdevices[0..n_devices];
}
