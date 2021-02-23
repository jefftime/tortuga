pub const c = @import("c").c;
pub const Device = @import("device.zig").Device;
pub const memory_zig = @import("memory.zig");
pub const MemoryUsage = memory_zig.MemoryUsage;
pub const Buffer = memory_zig.Buffer;

pub const Mesh = struct {
    vertices: Buffer,
    indices: Buffer,
    n_indices: usize,
    index_type: c.VkIndexType,

    pub fn init(
        out_mesh: *Mesh,
        device: *Device,
        vertex_data: []const f32,
        index_data: []const u16
    ) !void {
        var vertices = try device.memory.create_buffer(
            16,
            MemoryUsage.Vertex.value(),
            vertex_data.len * @sizeOf(f32)
        );
        var indices = try device.memory.create_buffer(
            16,
            MemoryUsage.Index.value(),
            index_data.len * @sizeOf(u16)
        );

        try vertices.write(f32, vertex_data);
        try indices.write(u16, index_data);

        out_mesh.* = Mesh {
            .vertices = vertices,
            .indices = indices,
            .n_indices = index_data.len,
            .index_type = c.VkIndexType.VK_INDEX_TYPE_UINT16
        };
    }

    pub fn init_large(
        out_mesh: *Mesh,
        device: *Device,
        vertex_data: []const f32,
        index_data: []const u32
    ) !void {
        var vertices = try device.memory.create_buffer(
            16,
            MemoryUsage.Vertex.value(),
            vertex_data.len * @sizeOf(f32)
        );
        var indices = try device.memory.create_buffer(
            16,
            MemoryUsage.Index.value(),
            index_data.len * @sizeOf(u32)
        );

        try vertices.write(f32, vertex_data);
        try indices.write(u32, index_data);

        out_mesh.* = Mesh {
            .vertices = vertices,
            .indices = indices,
            .n_indices = index_data.len,
            .index_type = c.VkIndexType.VK_INDEX_TYPE_UINT32
        };
    }

    pub fn deinit(self: *const Mesh) void {
        self.vertices.deinit();
        self.indices.deinit();
    }
};
