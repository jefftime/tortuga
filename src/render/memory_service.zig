const std = @import("std");
const c = @import("c").c;
const Device = @import("device.zig").Device;
const memory_zig = @import("memory.zig");
const Memory = memory_zig.Memory;
const MemoryUsage = memory_zig.MemoryUsage;

pub const MemoryService = struct {
    memory: Memory,
    // heaps: ?[]Memory,

    pub fn init(
        out_memory: *MemoryService,
        device: *Device,
        mem_size: usize
    ) !void {
        const usage =
            MemoryUsage.Vertex.value()
            | MemoryUsage.Index.value()
            | MemoryUsage.Uniform.value()
            | MemoryUsage.TransferSrc.value()
            | MemoryUsage.TransferDst.value();
        const memory = try Memory.init(device, .Cpu, usage, mem_size);

        out_memory.* = MemoryService {
            .memory = memory
        };
    }

    pub fn deinit(self: *const MemoryService) void {
        self.memory.deinit();
    }

    pub fn map(self: *MemoryService) !void {
        try self.memory.map();
    }

    pub fn unmap(self: *MemoryService) void {
        self.memory.unmap();
    }
};
