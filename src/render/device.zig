pub const std = @import("std");
pub const c = @import("c").c;
pub const Context = @import("context.zig").Context;
pub const Memory = @import("memory.zig").Memory;
pub const mem = @import("mem");
pub const alloc = mem.alloc;
pub const dealloc = mem.dealloc;

pub const DeviceBuilder = struct {
    context: *const Context,
    device_id: ?u32,
    memory_size: ?usize,

    pub fn init(context: *const Context) DeviceBuilder {
        return DeviceBuilder {
            .context = context,
            .device_id = null,
            .memory_size = null
        };
    }

    pub fn create(self: *DeviceBuilder) !Device {
        const id = self.device_id orelse return error.NoDeviceSelected;
        var device = try Device.init(self.context, id);
        if (self.memory_size) |size| try device.set_memory(size);

        return device;
    }

    pub fn with_device(self: *DeviceBuilder, device_id: u32) void {
        self.device_id = device_id;
    }

    pub fn with_memory(self: *DeviceBuilder, size: usize) void {
        self.memory_size = size;
    }

};

pub const Device = struct {
    pub var vkGetDeviceQueue: c.PFN_vkGetDeviceQueue = undefined;
    pub var vkCreateSemaphore: c.PFN_vkCreateSemaphore = undefined;
    pub var vkDestroySemaphore: c.PFN_vkDestroySemaphore = undefined;
    pub var vkCreatePipelineLayout: c.PFN_vkCreatePipelineLayout = undefined;
    pub var vkDestroyPipelineLayout: c.PFN_vkDestroyPipelineLayout = undefined;
    pub var vkCreateShaderModule: c.PFN_vkCreateShaderModule = undefined;
    pub var vkDestroyShaderModule: c.PFN_vkDestroyShaderModule = undefined;
    pub var vkCreateRenderPass: c.PFN_vkCreateRenderPass = undefined;
    pub var vkDestroyRenderPass: c.PFN_vkDestroyRenderPass = undefined;
    pub var vkCreateGraphicsPipelines:
        c.PFN_vkCreateGraphicsPipelines = undefined;
    pub var vkDestroyPipeline: c.PFN_vkDestroyPipeline = undefined;
    pub var vkCreateFramebuffer: c.PFN_vkCreateFramebuffer = undefined;
    pub var vkDestroyFramebuffer: c.PFN_vkDestroyFramebuffer = undefined;
    pub var vkCreateImageView: c.PFN_vkCreateImageView = undefined;
    pub var vkDestroyImageView: c.PFN_vkDestroyImageView = undefined;
    pub var vkCreateCommandPool: c.PFN_vkCreateCommandPool = undefined;
    pub var vkDestroyCommandPool: c.PFN_vkDestroyCommandPool = undefined;
    pub var vkAllocateCommandBuffers: c.PFN_vkAllocateCommandBuffers = undefined;
    pub var vkFreeCommandBuffers: c.PFN_vkFreeCommandBuffers = undefined;
    pub var vkBeginCommandBuffer: c.PFN_vkBeginCommandBuffer = undefined;
    pub var vkEndCommandBuffer: c.PFN_vkEndCommandBuffer = undefined;
    pub var vkCmdBeginRenderPass: c.PFN_vkCmdBeginRenderPass = undefined;
    pub var vkCmdEndRenderPass: c.PFN_vkCmdEndRenderPass = undefined;
    pub var vkCmdBindPipeline: c.PFN_vkCmdBindPipeline = undefined;
    pub var vkCmdBindVertexBuffers: c.PFN_vkCmdBindVertexBuffers = undefined;
    pub var vkCmdBindIndexBuffer: c.PFN_vkCmdBindIndexBuffer = undefined;
    pub var vkCmdDrawIndexed: c.PFN_vkCmdDrawIndexed = undefined;

    // Descriptors
    pub var vkCreateDescriptorPool: c.PFN_vkCreateDescriptorPool = undefined;
    pub var vkDestroyDescriptorPool: c.PFN_vkDestroyDescriptorPool = undefined;
    pub var vkCreateDescriptorSetLayout:
        c.PFN_vkCreateDescriptorSetLayout = undefined;
    pub var vkDestroyDescriptorSetLayout:
        c.PFN_vkDestroyDescriptorSetLayout = undefined;
    pub var vkAllocateDescriptorSets: c.PFN_vkAllocateDescriptorSets = undefined;
    pub var vkFreeDescriptorSets: c.PFN_vkFreeDescriptorSets = undefined;
    pub var vkUpdateDescriptorSets: c.PFN_vkUpdateDescriptorSets = undefined;
    pub var vkCmdBindDescriptorSets: c.PFN_vkCmdBindDescriptorSets = undefined;

    // Memory
    pub var vkCreateBuffer: c.PFN_vkCreateBuffer = undefined;
    pub var vkDestroyBuffer: c.PFN_vkDestroyBuffer = undefined;
    pub var vkGetBufferMemoryRequirements:
        c.PFN_vkGetBufferMemoryRequirements = undefined;
    pub var vkAllocateMemory: c.PFN_vkAllocateMemory = undefined;
    pub var vkFreeMemory: c.PFN_vkFreeMemory = undefined;
    pub var vkBindBufferMemory: c.PFN_vkBindBufferMemory = undefined;
    pub var vkMapMemory: c.PFN_vkMapMemory = undefined;
    pub var vkFlushMappedMemoryRanges:
        c.PFN_vkFlushMappedMemoryRanges = undefined;
    pub var vkInvalidateMappedMemoryRanges:
        c.PFN_vkInvalidateMappedMemoryRanges = undefined;
    pub var vkUnmapMemory: c.PFN_vkUnmapMemory = undefined;

    // Present
    pub var vkAcquireNextImageKHR: c.PFN_vkAcquireNextImageKHR = undefined;
    pub var vkQueueSubmit: c.PFN_vkQueueSubmit = undefined;
    pub var vkQueuePresentKHR: c.PFN_vkQueuePresentKHR = undefined;
    pub var vkQueueWaitIdle: c.PFN_vkQueueWaitIdle = undefined;

    context: *const Context,
    physical_device: usize,     // Index into context.devices
    props: c.VkPhysicalDeviceProperties,
    features: c.VkPhysicalDeviceFeatures,
    mem_props: c.VkPhysicalDeviceMemoryProperties,
    device: c.VkDevice,
    swapchain: ?c.VkSwapchainKHR,
    swapchain_images: []c.VkImage,
    image_semaphore: c.VkSemaphore,
    render_semaphore: c.VkSemaphore,
    graphics_queue: c.VkQueue,
    present_queue: c.VkQueue,
    graphics_index: u32,
    present_index: u32,
    memory: ?Memory,

    pub fn init(context: *const Context, device_id: usize) !Device {
        const physical_device = context.devices[device_id];
        var props: c.VkPhysicalDeviceProperties = undefined;
        var features: c.VkPhysicalDeviceFeatures = undefined;
        var mem_props: c.VkPhysicalDeviceMemoryProperties = undefined;

        Context.vkGetPhysicalDeviceProperties.?(physical_device, &props);
        Context.vkGetPhysicalDeviceFeatures.?(physical_device, &features);
        Context.vkGetPhysicalDeviceMemoryProperties.?(
            physical_device,
            &mem_props
        );

        std.log.info("selecting device `{}`", .{props.deviceName});

        var graphics_index: u32 = 0;
        var present_index: u32 = 0;
        try get_queue_information(
            physical_device,
            context.surface,
            &graphics_index,
            &present_index
        );
        std.log.info("found graphics queue index: {}", .{graphics_index});
        std.log.info("found present queue index: {}", .{present_index});

        const device = try create_device(
            context,
            physical_device,
            graphics_index,
            present_index
        );
        errdefer Context.vkDestroyDevice.?(device, null);
        std.log.info("created Vulkan device!", .{});

        try load_device_functions(device);
        const swapchain = try create_swapchain(
            physical_device,
            device,
            context.surface
        );
        const swapchain_images = try get_swapchain_images(device, swapchain);
        errdefer dealloc(swapchain_images.ptr);

        const image_semaphore = try create_semaphore(device);
        errdefer Device.vkDestroySemaphore.?(device, image_semaphore, null);
        const render_semaphore = try create_semaphore(device);
        errdefer Device.vkDestroySemaphore.?(device, render_semaphore, null);

        var graphics_queue: c.VkQueue = undefined;
        var present_queue: c.VkQueue = undefined;
        Device.vkGetDeviceQueue.?(
            device,
            graphics_index,
            0,
            &graphics_queue
        );
        Device.vkGetDeviceQueue.?(
            device,
            present_index,
            0,
            &present_queue
        );

        return Device {
            .context = context,
            .physical_device = device_id,
            .props = props,
            .features = features,
            .mem_props = mem_props,
            .device = device,
            .swapchain = swapchain,
            .swapchain_images = swapchain_images,
            .image_semaphore = image_semaphore,
            .render_semaphore = render_semaphore,
            .graphics_queue = graphics_queue,
            .present_queue = present_queue,
            .graphics_index = graphics_index,
            .present_index = present_index,
            .memory = null
        };
    }

    pub fn deinit(self: *const Device) void {
        if (self.memory) |m| m.deinit();
        dealloc(self.swapchain_images.ptr);
        Device.vkDestroySemaphore.?(self.device, self.image_semaphore, null);
        Device.vkDestroySemaphore.?(self.device, self.render_semaphore, null);
        if (self.swapchain) |s| {
            Context.vkDestroySwapchainKHR.?(self.device, s, null);
        }
        Context.vkDestroyDevice.?(self.device, null);
        std.log.info("destroying Device", .{});
    }

    pub fn set_memory(self: *Device, size: usize) !void {
        const usage = c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT
            | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT;
        self.memory = try Memory.init(self, usage, size);
    }

    pub fn recreate_swapchain(self: *Device) !void {
        dealloc(self.swapchain_images);
        Device.vkDestroySwapchainKHR.?(self.device, self.swapchain, null);

        self.swapchain = create_swapchain(
            self.physical_device,
            self.device,
            self.context.surface
        ) catch |err| {
            std.log.err("could not recreate swapchain", .{});
            self.swapchain = null;
            return err;
        };
        errdefer {
            Device.vkDestroySwapchainKHR.?(self.device, self.swapchain.?, null);
            self.swapchain = null;
        }

        self.swapchain_images = try get_swapchain_images(
            self.device,
            self.swapchain
        );
    }
};

fn get_queue_information(
    device: c.VkPhysicalDevice,
    surface: c.VkSurfaceKHR,
    out_graphics_index: *u32,
    out_present_index: *u32
) !void {
    var n_props: u32 = 0;
    Context.vkGetPhysicalDeviceQueueFamilyProperties.?(device, &n_props, null);
    if (n_props == 0) return error.NoDevices;
    var props = try alloc(c.VkQueueFamilyProperties, n_props);
    defer dealloc(props.ptr);
    Context.vkGetPhysicalDeviceQueueFamilyProperties.?(
        device,
        &n_props,
        props.ptr
    );

    var present_set = false;
    var present_index: u32 = undefined;
    var graphics_set = false;
    var graphics_index: u32 = undefined;
    var i: u32 = 0;
    while (i < n_props) : (i += 1) {
        const queue_count = props[i].queueCount;
        const graphics_support =
            props[i].queueFlags & @intCast(u32, c.VK_QUEUE_GRAPHICS_BIT);

        if (queue_count > 0 and graphics_support != 0) {
            graphics_set = true;
            graphics_index = i;
        }

        var present_support: c.VkBool32 = c.VK_FALSE;
        const result = Context.vkGetPhysicalDeviceSurfaceSupportKHR.?(
            device,
            i,
            surface,
            &present_support
        );
        if (result != c.VkResult.VK_SUCCESS) return error.BadSurfaceSupport;
        if (queue_count > 0 and present_support == c.VK_TRUE) {
            present_set = true;
            present_index = i;
        }
    }

    if (!graphics_set or !present_set) return error.MissingQueueIndices;
    out_graphics_index.* = graphics_index;
    out_present_index.* = present_index;
}

fn create_device(
    context: *const Context,
    physical_device: c.VkPhysicalDevice,
    graphics_index: u32,
    present_index: u32
) !c.VkDevice {
    const exts = [_][*c]const u8 { c.VK_KHR_SWAPCHAIN_EXTENSION_NAME };
    var priority: f32 = 1.0;
    var features: c.VkPhysicalDeviceFeatures = undefined;
    @memset(@ptrCast([*]u8, &features), 0, @sizeOf(c.VkPhysicalDeviceFeatures));

    var queue_infos: [2]c.VkDeviceQueueCreateInfo = undefined;
    var n_queues: u32 = if (graphics_index == present_index) 1 else 2;
    queue_infos[0] = c.VkDeviceQueueCreateInfo {
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueCount = 1,
        .queueFamilyIndex = graphics_index,
        .pQueuePriorities = &priority,
    };
    if (n_queues > 1) {
        queue_infos[1] = c.VkDeviceQueueCreateInfo {
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueCount = 1,
            .queueFamilyIndex = present_index,
            .pQueuePriorities = &priority,
        };
    }

    const create_info = c.VkDeviceCreateInfo {
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pEnabledFeatures = &features,
        .enabledExtensionCount = 1,
        .ppEnabledExtensionNames = &exts,
        .queueCreateInfoCount = n_queues,
        .pQueueCreateInfos = &queue_infos,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null
    };

    var device: c.VkDevice = undefined;
    const result = Context.vkCreateDevice.?(
        physical_device,
        &create_info,
        null,
        &device
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadDevice;

    return device;
}

fn load(prefix: c.VkDevice, comptime symbol: []const u8) !void {
    std.log.info("loading device function `{}`", .{symbol});
    const result = Context.vkGetDeviceProcAddr.?(prefix, symbol.ptr)
        orelse return error.BadFunctionLoad;

    @field(Device, symbol) = @ptrCast(@field(c, "PFN_" ++ symbol), result);
}

fn load_device_functions(device: c.VkDevice) !void {
    try load(device, "vkGetDeviceQueue");
    try load(device, "vkCreateSemaphore");
    try load(device, "vkDestroySemaphore");
    try load(device, "vkCreatePipelineLayout");
    try load(device, "vkDestroyPipelineLayout");
    try load(device, "vkCreateShaderModule");
    try load(device, "vkDestroyShaderModule");
    try load(device, "vkCreateRenderPass");
    try load(device, "vkDestroyRenderPass");
    try load(device, "vkCreateGraphicsPipelines");
    try load(device, "vkDestroyPipeline");
    try load(device, "vkCreateFramebuffer");
    try load(device, "vkDestroyFramebuffer");
    try load(device, "vkCreateImageView");
    try load(device, "vkDestroyImageView");
    try load(device, "vkCreateCommandPool");
    try load(device, "vkDestroyCommandPool");
    try load(device, "vkAllocateCommandBuffers");
    try load(device, "vkFreeCommandBuffers");
    try load(device, "vkBeginCommandBuffer");
    try load(device, "vkEndCommandBuffer");
    try load(device, "vkCmdBeginRenderPass");
    try load(device, "vkCmdEndRenderPass");
    try load(device, "vkCmdBindPipeline");
    try load(device, "vkCmdBindVertexBuffers");
    try load(device, "vkCmdBindIndexBuffer");
    try load(device, "vkCmdDrawIndexed");
    try load(device, "vkCreateDescriptorPool");
    try load(device, "vkDestroyDescriptorPool");
    try load(device, "vkCreateDescriptorSetLayout");
    try load(device, "vkDestroyDescriptorSetLayout");
    try load(device, "vkAllocateDescriptorSets");
    try load(device, "vkFreeDescriptorSets");
    try load(device, "vkUpdateDescriptorSets");
    try load(device, "vkCmdBindDescriptorSets");
    try load(device, "vkCreateBuffer");
    try load(device, "vkDestroyBuffer");
    try load(device, "vkGetBufferMemoryRequirements");
    try load(device, "vkAllocateMemory");
    try load(device, "vkFreeMemory");
    try load(device, "vkBindBufferMemory");
    try load(device, "vkMapMemory");
    try load(device, "vkFlushMappedMemoryRanges");
    try load(device, "vkInvalidateMappedMemoryRanges");
    try load(device, "vkUnmapMemory");
    try load(device, "vkAcquireNextImageKHR");
    try load(device, "vkQueueSubmit");
    try load(device, "vkQueuePresentKHR");
    try load(device, "vkQueueWaitIdle");
}

fn choose_format(formats: []c.VkSurfaceFormatKHR) c.VkSurfaceFormatKHR {
    // TODO: Make an intelligent decision lol
    std.log.info("select surface format {}", .{formats[0]});
    return formats[0];
}

fn choose_present_mode(modes: []c.VkPresentModeKHR) c.VkPresentModeKHR {
    // This is guaranteed to be supported, but we should have the ability to
    // change based on preference
    return c.VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR;
}

fn create_swapchain(
    physical_device: c.VkPhysicalDevice,
    device: c.VkDevice,
    surface: c.VkSurfaceKHR
) !c.VkSwapchainKHR {
    var caps: c.VkSurfaceCapabilitiesKHR = undefined;
    var result = Context.vkGetPhysicalDeviceSurfaceCapabilitiesKHR.?(
        physical_device,
        surface,
        &caps
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadSurfaceCapabilities;

    var n_formats: u32 = 0;
    result = Context.vkGetPhysicalDeviceSurfaceFormatsKHR.?(
        physical_device,
        surface,
        &n_formats,
        null
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadSurfaceCapabilities;
    if (n_formats == 0) return error.NoSurfaceFormats;
    var formats = try alloc(c.VkSurfaceFormatKHR, n_formats);
    defer dealloc(formats.ptr);
    result = Context.vkGetPhysicalDeviceSurfaceFormatsKHR.?(
        physical_device,
        surface,
        &n_formats,
        formats.ptr
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadSurfaceFormats;

    var n_present_modes: u32 = 0;
    result = Context.vkGetPhysicalDeviceSurfacePresentModesKHR.?(
        physical_device,
        surface,
        &n_present_modes,
        null
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadSurfacePresentModes;
    if (n_present_modes == 0) return error.NoPresentModes;
    var present_modes = try alloc(c.VkPresentModeKHR, n_present_modes);
    defer dealloc(present_modes.ptr);
    result = Context.vkGetPhysicalDeviceSurfacePresentModesKHR.?(
        physical_device,
        surface,
        &n_present_modes,
        present_modes.ptr
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadSurfacePresentModes;

    const selected_format = choose_format(formats);
    const create_info = c.VkSwapchainCreateInfoKHR {
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .pNext = null,
        .flags = 0,
        .surface = surface,
        .minImageCount = caps.minImageCount,
        .imageFormat = selected_format.format,
        .imageColorSpace = selected_format.colorSpace,
        .imageExtent = caps.currentExtent,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageSharingMode =
            c.VkSharingMode.VK_SHARING_MODE_EXCLUSIVE, // TODO: rework this
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
        .preTransform = caps.currentTransform,
        .compositeAlpha =
            c.VkCompositeAlphaFlagBitsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = choose_present_mode(present_modes),
        .clipped = c.VK_TRUE,
        .oldSwapchain = null,
    };
    var swapchain: c.VkSwapchainKHR = undefined;
    result = Context.vkCreateSwapchainKHR.?(
        device,
        &create_info,
        null,
        &swapchain
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadSwapchain;

    std.log.info("created swapchain", .{});

    return swapchain;
}

fn get_swapchain_images(
    device: c.VkDevice,
    swapchain: c.VkSwapchainKHR
) ![]c.VkImage {
    var n_images: u32 = 0;
    var result = Context.vkGetSwapchainImagesKHR.?(
        device,
        swapchain,
        &n_images,
        null
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadSwapchainImage;
    if (n_images == 0) return error.NoSwapchainImages;
    var images = try alloc(c.VkImage, n_images);
    result = Context.vkGetSwapchainImagesKHR.?(
        device,
        swapchain,
        &n_images,
        images.ptr
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadSwapchainImage;

    return images;
}

fn create_semaphore(device: c.VkDevice) !c.VkSemaphore {
    const create_info = c.VkSemaphoreCreateInfo {
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .pNext = null,
        .flags = 0
    };

    var semaphore: c.VkSemaphore = undefined;
    const result = Device.vkCreateSemaphore.?(
        device,
        &create_info,
        null,
        &semaphore
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadSemaphore;

    return semaphore;
}
