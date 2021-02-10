const std = @import("std");
const c = @import("c").c;
const Device = @import("device.zig").Device;
const memory_zig = @import("memory.zig");
const Memory = memory_zig.Memory;
const Buffer = memory_zig.Buffer;
const binding_zig = @import("binding.zig");
const Binding = binding_zig.Binding;
const attribute_zig = @import("attribute.zig");
const Shader = @import("shader.zig").Shader;

pub const PassBuilder = struct {
    // TODO: Implement multiple stages
    // const MAX_STAGES = 16;

    // const Stage = struct {
    //     bindings: []const Binding,
    //     vertex_shader: Shader,
    //     fragment_shader: Shader
    // };
    // const stages_buf: [MAX_STAGES]Stage = undefined;
    // const stages: ?[]Stage = null;

    device: *Device,
    uniform_memory: ?Memory,

    pub fn init(device: *Device) PassBuilder {
        return PassBuilder {
            .device = device,
            .uniform_memory = null
        };
    }

    pub fn with_uniform_memory(self: *PassBuilder, memory: *Memory) void {
        self.uniform_memory = memory;
    }

    pub fn create(
        self: *PassBuilder,
        pass: *Pass,
        vshader: Shader,
        fshader: Shader
    ) !void {
        pass.* = try Pass.init(
            self.device,
            self.uniform_memory,
            vshader,
            fshader
        );
    }
};

pub const Pass = struct {
    device: *Device,
    // descriptor_pool: c.VkDescriptorPool,
    // descriptor_layouts: []c.VkDescriptorSetLayout,
    // descriptor_sets: []c.VkDescriptorSet,
    // render_pass: c.VkRenderPass,
    // pipeline: c.VkPipeline,
    // pipeline_layout: c.VkPipelineLayout,
    // image_views: []c.VkImageView,
    // framebuffers: []c.VkFramebuffer,
    command_pool: c.VkCommandPool,
    // command_buffers: []c.VkCommandBuffer,
    uniform_memory: ?Memory,
    // vertices: Buffer,
    // indices: Buffer,
    // uniforms: []Buffer
    vshader: Shader,
    fshader: Shader,

    pub fn init(
        device: *Device,
        uniform_memory: ?Memory,
        vshader: Shader,
        fshader: Shader
    ) !Pass {
        const command_pool = try create_command_pool(device);
        errdefer Device.vkDestroyCommandPool.?(device, command_pool, null);

        return Pass {
            .device = device,
            .command_pool = command_pool,
            .uniform_memory = uniform_memory,
            .vshader = vshader,
            .fshader = fshader
        };
    }

    pub fn deinit(self: *const Pass) void {
        self.vshader.deinit();
        self.fshader.deinit();
        Device.vkDestroyCommandPool.?(
            self.device.device,
            self.command_pool,
            null
        );
        std.log.info("destroying Pass", .{});
    }
};

fn create_command_pool(device: *Device) !c.VkCommandPool {
    const create_info = c.VkCommandPoolCreateInfo {
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueFamilyIndex = device.graphics_index,
    };

    var pool: c.VkCommandPool = undefined;
    const result = Device.vkCreateCommandPool.?(
        device.device,
        &create_info,
        null,
        &pool
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadCommandPool;

    return pool;
}
