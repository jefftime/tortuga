const std = @import("std");
const c = @import("c").c;
const Device = @import("device.zig").Device;
const memory_zig = @import("memory.zig");
const Memory = memory_zig.Memory;
const Buffer = memory_zig.Buffer;

pub const BindingType = enum {
    Float32 = 4,
    Float64 = 8,
    Vec2 = 8,
    Vec3 = 12,
    Vec4 = 16
};

pub const Binding = struct {
    index: u32,
    size: u32,
    binding_type: BindingType
};

pub const PassBuilder = struct {
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

    pub fn add_stage(self: *PassBuilder) void {
    }

    pub fn with_bindings(
        self: *PassBuilder,
        vertex_size: u32,
        bindings: []Binding
    ) void {
        
    }

    pub fn create(self: *PassBuilder) !Pass {
        return Pass.init(self.device);
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
    // uniform_memory: Memory,
    // vertices: Buffer,
    // indices: Buffer,
    // uniforms: []Buffer

    pub fn init(device: *Device) !Pass {
        // var uniform_memory = try Memory.init(
        //     device,
        //     VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
        //     1 * 1024            // 1 MB
        // );
        // errdefer uniform_memory.deinit();

        const command_pool = try create_command_pool(device);
        errdefer Device.vkDestroyCommandPool.?(device, command_pool, null);

        return Pass {
            .device = device,
            .command_pool = command_pool
        };
    }

    pub fn deinit(self: *Pass) void {
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
