const c = @import("c").c;
const Device = @import("device.zig").Device;
const Binding = @import("binding.zig").Binding;
const mem = @import("mem");
const alloc = mem.alloc;
const dealloc = mem.dealloc;

pub const ShaderKind = enum {
    Vertex,
    Fragment
};

pub const Shader = struct {
    device: *const Device,
    shader: c.VkShaderModule,
    bindings: ?[]c.VkVertexInputBindingDescription,
    attrs: ?[]c.VkVertexInputAttributeDescription,
    kind: ShaderKind,

    pub fn init(
        device: *const Device,
        kind: ShaderKind,
        input_bindings: ?[]const []const Binding,
        shader: c.VkShaderModule
    ) !Shader {
        var attrs: ?[]c.VkVertexInputAttributeDescription = null;
        var bindings: ?[]c.VkVertexInputBindingDescription = null;
        if (input_bindings) |in_bindings| {
            var total_attrs: usize = 0;
            for (in_bindings) |b| total_attrs += b.len;
            attrs = try alloc(
                c.VkVertexInputAttributeDescription,
                total_attrs
            );
            errdefer dealloc(attrs.?.ptr);

            bindings = try alloc(
                c.VkVertexInputBindingDescription,
                in_bindings.len
            );
            errdefer dealloc(bindings.?.ptr);

            var cur_attr: usize = 0;
            var cur_location: u32 = 0;
            for (in_bindings) |binding, i| {
                var offset: u32 = 0;
                for (binding) |attribute| {
                    switch (attribute) {
                        .Vec3 => {
                            const T = c.VkVertexInputAttributeDescription;
                            attrs.?[cur_attr] = T {
                                .location = cur_location,
                                .binding = @intCast(u32, i),
                                .format = c.VkFormat.VK_FORMAT_R32G32B32_SFLOAT,
                                .offset = offset
                            };
                            cur_attr += 1;
                            cur_location += 1;
                            offset += @as(u32, @sizeOf(f32)) * 3;
                        },

                        else => return error.NotImplemented
                    }
                }

                bindings.?[i] = c.VkVertexInputBindingDescription {
                    .binding = @intCast(u32, i),
                    .stride = offset,
                    .inputRate = c.VkVertexInputRate.VK_VERTEX_INPUT_RATE_VERTEX,
                };
            }
        }

        return Shader {
            .device = device,
            .kind = kind,
            .shader = shader,
            .attrs = attrs,
            .bindings = bindings
        };
    }

    pub fn deinit(self: *const Shader) void {
        if (self.bindings) |b| dealloc(b.ptr);
        Device.vkDestroyShaderModule.?(self.device.device, self.shader, null);
    }
};
