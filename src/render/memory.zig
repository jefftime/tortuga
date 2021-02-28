const std = @import("std");
const c = @import("c").c;
const Device = @import("device.zig").Device;

pub const BufferType = enum {
    Cpu,
    Gpu
};

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
    buffer: c.VkBuffer,
    offset: usize,
    kind: BufferType,

    pub fn init(
        memory: *Memory,
        buffer: c.VkBuffer,
        kind: BufferType,
        offset: usize
    ) Buffer {
        return Buffer {
            .memory = memory,
            .buffer = buffer,
            .offset = offset,
            .kind = kind
        };
    }

    pub fn deinit(self: *const Buffer) void {}

    pub fn write(
        self: *Buffer,
        comptime T: type,
        in_data: []const T
    ) !void {
        switch (self.kind) {
            .Cpu => {
                const data = @ptrCast([*]const u8, in_data.ptr);
                var dst = self.memory.mapped_dst
                    orelse return error.MemoryUnmapped;

                @memcpy(dst + (self.offset), data, in_data.len * @sizeOf(T));
            },
            else => return error.NotImplemented
        }
    }
};

pub const Memory = struct {
    device: *const Device,
    size: usize,
    offset: usize,
    cpu_buffer: c.VkBuffer,
    cpu_memory: c.VkDeviceMemory,
    cpu_reqs: c.VkMemoryRequirements,
    gpu_buffer: c.VkBuffer,
    gpu_memory: c.VkDeviceMemory,
    gpu_reqs: c.VkMemoryRequirements,
    mapped_dst: ?[*]u8,

    pub fn init(
        device: *const Device,
        usage: u32,
        size: usize
    ) !Memory {
        // Create and bind backing buffers
        var cpu_buffer = try create_vkbuffer(device.device, size, usage);
        errdefer Device.vkDestroyBuffer.?(device.device, cpu_buffer, null);
        var cpu_reqs: c.VkMemoryRequirements = undefined;
        Device.vkGetBufferMemoryRequirements.?(
            device.device,
            cpu_buffer,
            &cpu_reqs
        );
        var cpu_memory = try bind_memory(
            device,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
            cpu_buffer,
            cpu_reqs
        );

        var gpu_buffer = try create_vkbuffer(device.device, size, usage);
        errdefer Device.vkDestroyBuffer.?(device.device, gpu_buffer, null);
        var gpu_reqs: c.VkMemoryRequirements = undefined;
        Device.vkGetBufferMemoryRequirements.?(
            device.device,
            gpu_buffer,
            &gpu_reqs
        );
        var gpu_memory = try bind_memory(
            device,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            gpu_buffer,
            gpu_reqs
        );

        return Memory {
            .device = device,
            .size = size,
            .offset = 0,
            .cpu_buffer = cpu_buffer,
            .cpu_memory = cpu_memory,
            .cpu_reqs = cpu_reqs,
            .gpu_buffer = gpu_buffer,
            .gpu_memory = gpu_memory,
            .gpu_reqs = gpu_reqs,
            .mapped_dst = null
        };
    }

    pub fn deinit(self: *const Memory) void {
        Device.vkDestroyBuffer.?(self.device.device, self.cpu_buffer, null);
        Device.vkDestroyBuffer.?(self.device.device, self.gpu_buffer, null);
        Device.vkFreeMemory.?(self.device.device, self.cpu_memory, null);
        Device.vkFreeMemory.?(self.device.device, self.gpu_memory, null);
        std.log.info("destroying Memory", .{});
    }

    pub fn create_buffer(
        self: *Memory,
        kind: BufferType,
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

        const req_align =
            if (kind == .Cpu) self.cpu_reqs.alignment
            else self.gpu_reqs.alignment;
        var buf_align = if (alignment < req_align) req_align else alignment;
        var next_offset = self.offset;
        if (self.offset % buf_align != 0) {
            next_offset = self.offset + (buf_align - (self.offset % buf_align));
        }

        if (next_offset > self.size) return error.OutOfMemory;

        self.offset = next_offset + size;

        return switch (kind) {
            .Cpu => Buffer.init(self, self.cpu_buffer, .Cpu, next_offset),
            .Gpu => Buffer.init(self, self.gpu_buffer, .Gpu, 0)
        };
    }

    pub fn reset(self: *Memory) void {
        self.offset = 0;
    }

    pub fn map(self: *Memory) !void {
        self.mapped_dst = undefined;
        const result = Device.vkMapMemory.?(
            self.device.device,
            self.cpu_memory,
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
            .memory = self.cpu_memory,
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

        Device.vkUnmapMemory.?(self.device.device, self.cpu_memory);

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
        &device.mem_props,
        reqs.memoryTypeBits,
        kind
        // c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT
        //     | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
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
