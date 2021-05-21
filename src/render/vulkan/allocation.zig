const std = @import("std");

usingnamespace @import("../../c.zig");
usingnamespace @import("device.zig");
usingnamespace @import("heap.zig");

const MemoryUsage = enum(u32) {
    Uniform = c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
    Vertex = c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
    Index = c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
    TransferSrc = c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
    TransferDst = c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,

    pub fn value(self: *const MemoryUsage) u32 {
        return @enumToInt(self.*);
    }
};

pub const Allocation = struct {
    size: usize,
    device: *const Device,
    heap: *const Heap,
    offset: usize,
    buffer: c.VkBuffer,
    memory: c.VkDeviceMemory,
    reqs: c.VkMemoryRequirements,
    mapped_dst: ?[*]u8,
    refs: usize,

    pub fn init(
        self: *Allocation,
        device: *const Device,
        heap: *const Heap,
        size: usize
    ) !void {
        var buffer = try create_vkbuffer(device.device, size, heap.usage);
        errdefer Device.vkDestroyBuffer.?(device.device, buffer, null);

        var reqs: c.VkMemoryRequirements = undefined;
        Device.vkGetBufferRequirements.?(device.device, buffer, &reqs);
        const mem_kind = switch (heap.kind) {
            .Cpu => c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
            .Gpu => c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
        };
        var memory = try bind_memory(
            device,
            @intCast(u32, mem_kind),
            buffer,
            reqs
        );

        self.* = Allocation {
            .size = size,
            .device = device,
            .heap = heap
        };
    }

    pub fn deinit(self: *Allocation) void {}
};
