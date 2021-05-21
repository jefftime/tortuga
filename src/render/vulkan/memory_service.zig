const std = @import("std");

usingnamespace @import("../../c.zig");
usingnamespace @import("../../mem.zig");
usingnamespace @import("device.zig");
usingnamespace @import("allocation.zig");
usingnamespace @import("memory.zig");
usingnamespace @import("heap.zig");

pub const MAX_ALLOCATIONS: u32 = 512;

pub const MemoryService = struct {
    heaps: []Heap,
    allocations: []Allocation,
    n_allocations: usize,

    pub fn init(out_memory: *MemoryService, device: *Device) !void {
        // const usage =
        //     MemoryUsage.Vertex.value()
        //     | MemoryUsage.Index.value()
        //     | MemoryUsage.Uniform.value()
        //     | MemoryUsage.TransferSrc.value()
        //     | MemoryUsage.TransferDst.value();
        // const memory = try Memory.init(device, .Cpu, usage, mem_size);

        var heaps = try alloc(Heap, device.mem_props.memoryHeapCount);
        errdefer dealloc(heaps.ptr);

        for (heaps) |*heap, i| {
            const property_flags =
                device.mem_props.memoryTypes[i].propertyFlags;

            heap.* = Heap {
                .index = i,
                .property_flags = property_flags,
                .size = device.mem_props.memoryHeaps[i].size,
                .free = device.mem_props.memoryHeaps[i].size
            };
        }

        // TODO: Make this a linked list
        var n_allocations = device.props.limits.maxMemoryAllocationCount;
        if (n_allocations > MAX_ALLOCATIONS) n_allocations = MAX_ALLOCATIONS;
        const allocations = try alloc(Allocation, n_allocations);
        errdefer dealloc(allocations.ptr);

        std.log.info("Allocation size: {} Total size: {}", .{
            @sizeOf(Allocation),
            @sizeOf(Allocation) * n_allocations
        });

        out_memory.* = MemoryService {
            .heaps = heaps,
            .allocations = allocations,
            .n_allocations = 0
        };
    }

    pub fn deinit(self: *MemoryService) void {
        for (self.allocations[0..self.n_allocations]) |*a| a.deinit();
        dealloc(self.allocations.ptr);
        dealloc(self.heaps.ptr);
    }

    pub fn allocate(self: *MemoryService, kind: HeapType, size: usize) !Buffer {
        return error.NotYet;
    }
};
