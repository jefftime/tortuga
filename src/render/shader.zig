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
    bindings: ?[]Binding,
    kind: ShaderKind,

    pub fn init(
        device: *const Device,
        kind: ShaderKind,
        input_bindings: ?[]const Binding,
        shader: c.VkShaderModule
    ) !Shader {
        const bindings = if (input_bindings) |in| blk: {
            // We want to own the incoming binding memory
            var bindings = try alloc(Binding, in.len);
            for (bindings) |*b, i| {
                b.* = in[i];
            }

            break :blk bindings;
        } else blk: {
            break :blk null;
        };

        return Shader {
            .device = device,
            .kind = kind,
            .shader = shader,
            .bindings = bindings
        };
    }

    pub fn deinit(self: *const Shader) void {
        if (self.bindings) |b| dealloc(b.ptr);
        Device.vkDestroyShaderModule.?(self.device.device, self.shader, null);
    }
};
