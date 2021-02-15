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
const alloc = @import("mem").alloc;
const dealloc = @import("mem").dealloc;

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
    vertices: Buffer,
    indices: Buffer,
    descriptor_layouts: []c.VkDescriptorSetLayout,
    descriptor_pool: c.VkDescriptorPool,

    // TODO: change arguments `vshader` and `fshader` to a single slice of
    // Shaders
    pub fn init(
        device: *Device,
        uniform_memory: ?Memory,
        vshader: Shader,
        fshader: Shader
    ) !Pass {
        const command_pool = try create_command_pool(device);
        errdefer Device.vkDestroyCommandPool.?(
            device.device,
            command_pool,
            null
        );

        var vertices: Buffer = undefined;
        var indices: Buffer = undefined;
        try create_vertex_data(device, &vertices, &indices);
        errdefer vertices.deinit();
        errdefer indices.deinit();

        const descriptor_layout_bindings: []const c.VkDescriptorSetLayoutBinding
            = &[_]c.VkDescriptorSetLayoutBinding {
                c.VkDescriptorSetLayoutBinding {
                    .binding = 0,
                    .descriptorType =
                        c.VkDescriptorType.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                    .descriptorCount = 1,
                    .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
                    .pImmutableSamplers = null
                }
        };
        const descriptor_layout_info = c.VkDescriptorSetLayoutCreateInfo {
            .sType = c.VkStructureType
                .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .bindingCount = 1,
            .pBindings = descriptor_layout_bindings.ptr
        };
        var descriptor_layouts = try create_descriptor_layouts(
            device,
            &descriptor_layout_info
        );
        errdefer {
            for (descriptor_layouts) |layout| {
                Device.vkDestroyDescriptorSetLayout.?(
                    device.device,
                    layout,
                    null
                );
            }
            dealloc(descriptor_layouts.ptr);
        }
        var descriptor_pool = try create_descriptor_pool(device);
        errdefer Device.vkDestroyDescriptorPool.?(
            device.device,
            descriptor_pool,
            null
        );

        return Pass {
            .device = device,
            .command_pool = command_pool,
            .uniform_memory = uniform_memory,
            .vshader = vshader,
            .fshader = fshader,
            .vertices = vertices,
            .indices = indices,
            .descriptor_layouts = descriptor_layouts,
            .descriptor_pool = descriptor_pool
        };
    }

    pub fn deinit(self: *const Pass) void {
        std.log.info("destroy descriptor pool", .{});
        Device.vkDestroyDescriptorPool.?(
            self.device.device,
            self.descriptor_pool,
            null
        );
        std.log.info("destroying descriptor layouts", .{});
        for (self.descriptor_layouts) |layout| {
            Device.vkDestroyDescriptorSetLayout.?(
                self.device.device,
                layout,
                null
            );
        }
        dealloc(self.descriptor_layouts.ptr);

        self.vertices.deinit();
        self.indices.deinit();
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

fn create_vertex_data(
    device: *Device,
    out_verts: *Buffer,
    out_indices: *Buffer
) !void {
    const vertex_data = [_]f32 {
        -0.5, -0.5, 0.0, 1.0, 0.0, 0.0,
        -0.5,  0.5, 0.0, 0.0, 1.0, 0.0,
         0.5,  0.5, 0.0, 1.0, 1.0, 1.0,
         0.5, -0.5, 0.0, 0.0, 1.0, 0.0
    };
    const index_data = [_]u16 { 0, 1, 2, 2, 3, 0 };

    // TODO: Don't hard error
    if (device.memory) |*m| {
        out_verts.* = try m.create_buffer(
            16,
            c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            vertex_data.len
        );
        out_indices.* = try m.create_buffer(
            16,
            c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
            index_data.len
        );
    } else {
        return error.NoDeviceMemory;
    }

    try out_verts.write(f32, &vertex_data);
    try out_indices.write(u16, &index_data);
}

fn create_descriptor_layouts(
    device: *const Device,
    descriptor_layout_info: *const c.VkDescriptorSetLayoutCreateInfo
) ![]c.VkDescriptorSetLayout {
    var layouts = try alloc(
        c.VkDescriptorSetLayout,
        device.swapchain_images.len
    );
    errdefer dealloc(layouts.ptr);

    for (layouts) |*layout| {
        const result = Device.vkCreateDescriptorSetLayout.?(
            device.device,
            descriptor_layout_info,
            null,
            layout
        );
        if (result != c.VkResult.VK_SUCCESS) return error.BadDescriptorSetLayout;
        errdefer Device.vkDestroyDescriptorSetLayout.?(
            device.device,
            layout,
            null
        );
    }

    return layouts;
}

fn create_descriptor_pool(device: *const Device) !c.VkDescriptorPool {
    const size = c.VkDescriptorPoolSize {
        .descriptorCount = @intCast(u32, device.swapchain_images.len),
        .type = c.VkDescriptorType.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
    };
    const create_info = c.VkDescriptorPoolCreateInfo {
        .sType =
            c.VkStructureType.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .maxSets = @intCast(u32, device.swapchain_images.len),
        .poolSizeCount = 1,
        .pPoolSizes = &size
    };

    var pool: c.VkDescriptorPool = undefined;
    const result = Device.vkCreateDescriptorPool.?(
        device.device,
        &create_info,
        null,
        &pool
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadDescriptorPool;

    return pool;
}
