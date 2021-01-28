pub const std = @import("std");
pub const c = @import("c").c;
pub const Context = @import("context.zig").Context;
pub const mem = @import("mem");
pub const alloc = mem.alloc;
pub const dealloc = mem.dealloc;

pub const Device = struct {
    context: *const Context,
    physical_device: usize,     // Index into context.devices
    device: c.VkDevice,
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

        var graphics_index: u32 = undefined;
        var present_index: u32 = undefined;
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

        try load_device_functions(device);

        return Device {
            .context = context,
            .physical_device = device_id,
            .device = device
        };
    }

    pub fn deinit(self: *const Device) void {
        std.log.info("destroy Device", .{});
        Context.vkDestroyDevice.?(self.device, null);
    }
};

fn get_queue_information(
    device: c.VkPhysicalDevice,
    surface: c.VkSurfaceKHR,
    out_graphics_index: *u32,
    out_present_index: *u32
) !void {
    var n_props: u32 = undefined;
    Context.vkGetPhysicalDeviceQueueFamilyProperties.?(device, &n_props, null);
    if (n_props == 0) return error.NoDevices;
    var props = try alloc(c.VkQueueFamilyProperties, n_props);
    defer dealloc(props.ptr);
}

fn create_device(
    context: *const Context,
    physical_device: c.VkPhysicalDevice,
    graphics_index: u32,
    present_index: u32
) !c.VkDevice {
    const exts = [_][*c]const u8 { c.VK_KHR_SWAPCHAIN_EXTENSION_NAME };
    var n_queues: u32 = 1;
    var priority: f32 = 1.0;
    var features: c.VkPhysicalDeviceFeatures = undefined;
    @memset(@ptrCast([*]u8, &features), 0, @sizeOf(c.VkPhysicalDeviceFeatures));

    var queue_infos = [_]c.VkDeviceQueueCreateInfo {
        c.VkDeviceQueueCreateInfo{
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueCount = 1,
            .queueFamilyIndex = graphics_index,
            .pQueuePriorities = &priority,
        },
        c.VkDeviceQueueCreateInfo {
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueCount = 1,
            .queueFamilyIndex = present_index,
            .pQueuePriorities = &priority,
        }
    };
    const create_info = c.VkDeviceCreateInfo {
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pEnabledFeatures = &features,
        .enabledExtensionCount = 1,
        .ppEnabledExtensionNames = &exts,
        .queueCreateInfoCount = n_queues, // TODO: allow for this to change
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
