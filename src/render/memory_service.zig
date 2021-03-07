
pub const MemoryService = struct {
    

    pub fn init(device: *Device) !void {
        
    }

    pub fn deinit(self: *MemoryService) void {}

    pub fn gpu_write(
        self: *MemoryService,
        comptime T: anytype,
        data: []T
    ) !void {
        return error.NotImplemented;
    }
};
