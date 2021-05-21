usingnamespace @import("../../c.zig");
usingnamespace @import("../../mem.zig");
usingnamespace @import("device.zig");
usingnamespace @import("allocation.zig");

pub const HeapType = enum {
    Cpu,
    Gpu,

    pub fn value(self: HeapType) u32 {
        switch (self) {
            .Cpu => @enumToInt(HeapType.Cpu),
            .Gpu => @enumToInt(HeapType.Gpu),
        }
    }
};

pub const Heap = struct {
    index: usize,
    property_flags: u32,
    size: usize,
    free: usize
};

