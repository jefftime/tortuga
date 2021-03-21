usingnamespace @import("c");
usingnamespace @import("memory.zig");

pub const BufferType = enum {
    Cpu,
    Gpu
};

pub const Buffer = struct {
    memory: *Memory,
    buffer: c.VkBuffer,
    offset: usize,
    kind: BufferType,
    size: usize,

    pub fn init(
        memory: *Memory,
        buffer: c.VkBuffer,
        kind: BufferType,
        offset: usize,
        size: usize
    ) Buffer {
        return Buffer {
            .memory = memory,
            .buffer = buffer,
            .offset = offset,
            .kind = kind,
            .size = size
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

            .Gpu => {
                return error.InvalidBufferWrite;
            }
        }
    }

    pub fn copy_from(self: *Buffer, rhs: *Buffer) !void {
        var cmd = try self.memory.device.create_command_buffer();
        defer Device.vkFreeCommandBuffers.?(
            self.memory.device.device,
            self.memory.device.command_pool,
            1,
            &cmd
        );

        const begin_info = c.VkCommandBufferBeginInfo {
            .sType =
                c.VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pNext = null,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pInheritanceInfo = null
        };
        _ = Device.vkBeginCommandBuffer.?(cmd, &begin_info);
        const copy_info = c.VkBufferCopy {
            .srcOffset = rhs.offset,
            .dstOffset = self.offset,
            .size = rhs.size
        };
        _ = Device.vkCmdCopyBuffer.?(
            cmd,
            rhs.memory.buffer,
            self.memory.buffer,
            1,
            &copy_info
        );
        _ = Device.vkEndCommandBuffer.?(cmd);
        const submit_info = c.VkSubmitInfo {
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .pNext = null,
            .waitSemaphoreCount = 0,
            .pWaitSemaphores = null,
            .pWaitDstStageMask = 0,
            .commandBufferCount = 1,
            .pCommandBuffers = &cmd,
            .signalSemaphoreCount = 0,
            .pSignalSemaphores = null
        };
        _ = Device.vkQueueSubmit.?(
            self.memory.device.graphics_queue,
            1,
            &submit_info,
            null
        );
        _ = Device.vkQueueWaitIdle.?(self.memory.device.graphics_queue);
    }
};
