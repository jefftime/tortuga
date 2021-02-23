const std = @import("std");
const c = @import("c").c;
const Device = @import("device.zig").Device;

pub const MemoryUsage = enum(u32) {
    Uniform = c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
    Vertex = c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
    Index = c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,

    pub fn value(self: *const MemoryUsage) u32 {
        return @enumToInt(self.*);
    }
};

pub const Buffer = struct {
    memory: *Memory,
    offset: usize,

    pub fn init(memory: *Memory, offset: usize) Buffer {
        return Buffer {
            .memory = memory,
            .offset = offset
        };
    }

    pub fn deinit(self: *const Buffer) void {}

    pub fn write(
        self: *Buffer,
        comptime T: type,
        in_data: []const T
    ) !void {
        const data = @ptrCast([*]const u8, in_data.ptr);
        var dst = self.memory.mapped_dst orelse return error.MemoryUnmapped;

        @memcpy(dst + (self.offset), data, in_data.len * @sizeOf(T));
    }
};

pub const Memory = struct {
    device: *const Device,
    reqs: c.VkMemoryRequirements,
    size: usize,
    offset: usize,
    buffer: c.VkBuffer,
    memory: c.VkDeviceMemory,
    mapped_dst: ?[*]u8,

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

        result = Device.vkBindBufferMemory.?(
            device.device,
            buffer,
            memory,
            0
        );
        if (result != c.VkResult.VK_SUCCESS) return error.BadBufferBind;

        return Memory {
            .device = device,
            .reqs = reqs,
            .size = size,
            .offset = 0,
            .buffer = buffer,
            .memory = memory,
            .mapped_dst = null
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
        usage: u32,
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

        var buf_align =
            if (alignment < self.reqs.alignment) self.reqs.alignment
            else alignment;
        var next_offset = self.offset;
        if (self.offset % buf_align != 0) {
            next_offset = self.offset + (buf_align - (self.offset % buf_align));
        }

        self.offset = next_offset + size;

        return Buffer.init(self, next_offset);
    }

    pub fn reset(self: *Memory) void {
        self.offset = 0;
    }

    pub fn map(self: *Memory) !void {
        self.mapped_dst = undefined;
        const result = Device.vkMapMemory.?(
            self.device.device,
            self.memory,
            0,
            c.VK_WHOLE_SIZE,
            0,
            @ptrCast([*c]?*c_void, &self.mapped_dst.?)
        );
        if (result != c.VkResult.VK_SUCCESS) return error.BadMemoryMap;
    }

    pub fn unmap(self: *Memory) void {
        const range = c.VkMappedMemoryRange {
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
            .pNext = null,
            .memory = self.memory,
            .offset = 0,
            .size = c.VK_WHOLE_SIZE
        };

        var result = Device.vkFlushMappedMemoryRanges.?(
            self.device.device,
            1,
            &range
        );
        if (result != c.VkResult.VK_SUCCESS) {
            std.log.err("unabled to flush mapped memory ranges", .{});
        }

        result = Device.vkInvalidateMappedMemoryRanges.?(
            self.device.device,
            1,
            &range
        );
        if (result != c.VkResult.VK_SUCCESS) {
            std.log.err("unable to invalidate mapped memory ranges", .{});
        }

        Device.vkUnmapMemory.?(self.device.device, self.memory);

        self.mapped_dst = null;
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
