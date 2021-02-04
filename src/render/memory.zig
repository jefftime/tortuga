const std = @import("std");
const c = @import("c").c;
const Device = @import("device.zig").Device;

pub const Memory = struct {
    device: *const Device,
    size: usize,
    offset: usize,
    buffer: c.VkBuffer,
    memory: c.VkDeviceMemory,

    pub fn init(
        device: *const Device,
        usage: u32,
        size: usize
    ) !Memory {
        // This is the backing buffer for the memory section
        const create_info = c.VkBufferCreateInfo {
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .sharingMode = c.VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
            .size = size,
            .usage = usage,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null
        };
        var buffer: c.VkBuffer = undefined;
        var result = Device.vkCreateBuffer.?(
            device.device,
            &create_info,
            null,
            &buffer
        );
        if (result != c.VkResult.VK_SUCCESS) return error.BadBuffer;
        errdefer Device.vkDestroyBuffer.?(device.device, buffer, null);

        var reqs: c.VkMemoryRequirements = undefined;
        Device.vkGetBufferMemoryRequirements.?(
            device.device,
            buffer,
            &reqs
        );
        const index = get_heap_index(
            &device.mem_props,
            reqs.memoryTypeBits,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT
                | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
        ) orelse return error.BadHeadIndex;

        const alloc_info = c.VkMemoryAllocateInfo {
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = reqs.size,
            .memoryTypeIndex = index,
        };
        var memory: c.VkDeviceMemory = undefined;
        result = Device.vkAllocateMemory.?(
            device.device,
            &alloc_info,
            null,
            &memory
        );
        if (result != c.VkResult.VK_SUCCESS) return error.BadAllocation;

        return Memory {
            .device = device,
            .size = size,
            .offset = 0,
            .buffer = buffer,
            .memory = memory
        };
    }

    pub fn deinit(self: *const Memory) void {
        Device.vkDestroyBuffer.?(self.device.device, self.buffer, null);
        Device.vkFreeMemory.?(self.device.device, self.memory, null);
        std.log.info("destroying Memory", .{});
    }
};

fn get_heap_index(
    props: *const c.VkPhysicalDeviceMemoryProperties,
    type_bit: u32,
    flags: c.VkMemoryPropertyFlags
) ?u32 {
    var i: u6 = 0;
    while (i < props.memoryTypeCount) : (i += 1) {
        if (type_bit & (@as(u64, 1) << i) != 0) {
            if (props.memoryTypes[i].propertyFlags & flags != 0) return i;
        }
    }

    return null;
}
