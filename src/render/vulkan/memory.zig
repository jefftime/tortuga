const std = @import("std");

usingnamespace @import("../../c.zig");
usingnamespace @import("device.zig");
usingnamespace @import("buffer.zig");

pub const MemoryType = enum(u32) {
    Cpu = 0x01,
    Gpu = 0x02
};

pub const MemoryUsage = enum(u32) {
    Uniform = c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
    Vertex = c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
    Index = c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
    TransferSrc = c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
    TransferDst = c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,

    pub fn value(self: *const MemoryUsage) u32 {
        return @enumToInt(self.*);
    }
};

pub const Memory = struct {
    var cpu_index: u32 = undefined;
    var gpu_index: u32 = undefined;

    device: *const Device,
    kind: MemoryType,
    size: usize,
    offset: usize,
    buffer: c.VkBuffer,
    memory: c.VkDeviceMemory,
    reqs: c.VkMemoryRequirements,
    mapped_dst: ?[*]u8,

    pub fn init(
        device: *const Device,
        kind: MemoryType,
        usage: u32,
        size: usize
    ) !Memory {
        // Create and bind backing buffers
        var buffer = try create_vkbuffer(device.device, size, usage);
        errdefer Device.vkDestroyBuffer.?(device.device, buffer, null);

        var reqs: c.VkMemoryRequirements = undefined;
        Device.vkGetBufferMemoryRequirements.?(device.device, buffer, &reqs);
        const mem_kind = switch (kind) {
            .Cpu => c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
            .Gpu => c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
        };
        var memory = try bind_memory(
            device,
            @intCast(u32, mem_kind),
            buffer,
            reqs
        );

        return Memory {
            .device = device,
            .kind = kind,
            .size = size,
            .offset = 0,
            .buffer = buffer,
            .memory = memory,
            .reqs = reqs,
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

        const req_align = self.reqs.alignment;
        var buf_align = if (alignment < req_align) req_align else alignment;
        var next_offset = self.offset;
        if (self.offset % buf_align != 0) {
            next_offset = self.offset + (buf_align - (self.offset % buf_align));
        }

        if (next_offset > self.size) return error.OutOfMemory;

        self.offset = next_offset + size;

        return Buffer.init(self, self.buffer, self.kind, next_offset, size);
    }

    pub fn reset(self: *Memory) void {
        self.offset = 0;
    }

    pub fn map(self: *Memory) !void {
        if (self.kind == .Gpu) return error.InvalidMemoryMap;

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

fn create_vkbuffer(device: c.VkDevice, size: usize, usage: u32) !c.VkBuffer {
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
    var result = Device.vkCreateBuffer.?(device, &create_info, null, &buffer);
    if (result != c.VkResult.VK_SUCCESS) return error.BadBuffer;

    return buffer;
}

fn bind_memory(
    device: *const Device,
    kind: u32,
    buf: c.VkBuffer,
    reqs: c.VkMemoryRequirements
) !c.VkDeviceMemory {
    const index = get_heap_index(
        device.mem_props,
        reqs.memoryTypeBits,
        kind
    ) orelse return error.BadHeapIndex;

    const alloc_info = c.VkMemoryAllocateInfo {
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = null,
        .allocationSize = reqs.size,
        .memoryTypeIndex = index,
    };
    var memory: c.VkDeviceMemory = undefined;
    var result = Device.vkAllocateMemory.?(
        device.device,
        &alloc_info,
        null,
        &memory
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadAllocation;

    result = Device.vkBindBufferMemory.?(device.device, buf, memory, 0);
    if (result != c.VkResult.VK_SUCCESS) return error.BadBufferBind;

    return memory;
}

fn get_heap_index(
    props: c.VkPhysicalDeviceMemoryProperties,
    type_bit: u32,
    flags: c.VkMemoryPropertyFlags
) ?u32 {
    var i: u6 = 0;
    while (i < props.memoryTypeCount) : (i += 1) {
        if (type_bit & (@as(u64, 1) << i) != 0) {
            if (props.memoryTypes[i].propertyFlags & flags != 0) {
                return i;
            }
        }
    }

    return null;
}
