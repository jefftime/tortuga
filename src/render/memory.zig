const std = @import("std");
const c = @import("c").c;
const Device = @import("device.zig").Device;

pub const Buffer = struct {
    memory: *Memory,
    offset: usize,
    buffer: c.VkBuffer,

    pub fn init(memory: *Memory, offset: usize, buffer: c.VkBuffer) Buffer {
        return Buffer {
            .memory = memory,
            .offset = offset,
            .buffer = buffer
        };
    }

    pub fn deinit(self: *const Buffer) void {
        Device.vkDestroyBuffer.?(self.memory.device.device, self.buffer, null);
    }

    pub fn write(self: *Buffer, comptime T: type, in_data: []const T) !void {
        const data = @ptrCast(
            [*]const u8,
            @alignCast(4, in_data.ptr)
            // @alignCast(@alignOf([*]const T), in_data.ptr)
        )[0..in_data.len/@sizeOf(T)];

        const alignment = self.memory.device.props.limits.nonCoherentAtomSize;
        const begin = self.offset - (self.offset % alignment);
        const len = data.len + (alignment - (data.len % alignment));
        const range = c.VkMappedMemoryRange {
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
            .pNext = null,
            .memory = self.memory.memory,
            .offset = begin,
            .size = len,
        };

        var dst: [*]u8 = undefined;
        var result = Device.vkMapMemory.?(
            self.memory.device.device,
            range.memory,
            range.offset,
            range.size,
            0,
            @ptrCast([*c]?*c_void, &dst)
        );
        if (result != c.VkResult.VK_SUCCESS) return error.BadVulkanMemoryMap;
        @memcpy(dst + (self.offset - begin), @ptrCast([*]const u8, data), len);
        _ = Device.vkFlushMappedMemoryRanges.?(
            self.memory.device.device,
            1,
            &range
        );
        _ = Device.vkInvalidateMappedMemoryRanges.?(
            self.memory.device.device,
            1,
            &range
        );
        Device.vkUnmapMemory.?(self.memory.device.device, self.memory.memory);
    }
};

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

    pub fn create_buffer(
        self: *Memory,
        alignment: usize,
        usage: c.VkBufferUsageFlags,
        size: usize
    ) !Buffer {
        const create_info = c.VkBufferCreateInfo {
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .sharingMode = c.VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
            .usage = usage,
            .size = size,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null
        };

        var buffer: c.VkBuffer = undefined;
        var result = Device.vkCreateBuffer.?(
            self.device.device,
            &create_info,
            null,
            &buffer
        );
        if (result != c.VkResult.VK_SUCCESS) return error.BadBuffer;
        errdefer Device.vkDestroyBuffer.?(self.device.device, buffer, null);

        var reqs: c.VkMemoryRequirements = undefined;
        Device.vkGetBufferMemoryRequirements.?(
            self.device.device,
            buffer,
            &reqs
        );

        var buf_align =
            if (alignment < reqs.alignment) reqs.alignment
            else alignment;
        var next_offset = self.offset;
        if (self.offset % buf_align != 0) {
            next_offset = self.offset + (buf_align - (self.offset % buf_align));
        }

        result = Device.vkBindBufferMemory.?(
            self.device.device,
            buffer,
            self.memory,
            next_offset
        );
        if (result != c.VkResult.VK_SUCCESS) return error.BadBufferBind;
        self.offset = next_offset + size;

        return Buffer.init(self, self.offset, buffer);
    }

    pub fn reset(self: *Memory) void {
        self.offset = 0;
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
