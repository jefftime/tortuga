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
const mem = @import("mem");
const new = mem.new;
const alloc = mem.alloc;
const dealloc = mem.dealloc;

const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

const Mat4 = extern struct {
    data: [16]f32
};

const Uniforms = extern struct {
    color: Vec3 align(4),
    m: Mat4 align(4)
};

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
    uniform_memory: ?*Memory,

    pub fn init(device: *Device) PassBuilder {
        return PassBuilder {
            .device = device,
            .uniform_memory = null
        };
    }

    pub fn with_uniform_memory(self: *PassBuilder, size: usize) void {
        var uniform_memory: ?Memory = Memory.init(
            self.device,
            c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            size
        ) catch |err| null;

        if (uniform_memory) |um| {
            self.uniform_memory = new(Memory) catch |_| {
                std.log.err("could not create uniform memory", .{});
                um.deinit();
                return;
            };

            self.uniform_memory.?.* = um;
        }
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
    uniform_memory: ?*Memory,
    vshader: Shader,
    fshader: Shader,
    vertices: Buffer,
    indices: Buffer,
    descriptor_layouts: []c.VkDescriptorSetLayout,
    descriptor_pool: c.VkDescriptorPool,
    uniforms: []Buffer,
    pipeline_layout: c.VkPipelineLayout,
    render_pass: c.VkRenderPass,
    pipeline: c.VkPipeline,

    // TODO: change arguments `vshader` and `fshader` to a single slice of
    // Shaders
    pub fn init(
        device: *Device,
        uniform_memory: ?*Memory,
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

        // TODO: Make this optional
        if (uniform_memory == null) return error.NoUniformMemory;
        var uniforms = try create_uniform_buffers(uniform_memory.?);
        for (uniforms) |*u| {
            const data: Uniforms align(4) = Uniforms {
                .color = Vec3 { .x = 1, .y = 2, .z = 3 },
                .m = Mat4 {
                    .data = [_]f32 {
                        1, 1, 1, 0,
                        0, 0, 0, 0,
                        0, 0, 0, 0,
                        0, 0, 0, 0
                    },
                }
            };
            try u.write(Uniforms, &[_]Uniforms { data });
        }

        var pipeline_layout = try create_pipeline_layout(
            device,
            descriptor_layouts
        );
        errdefer Device.vkDestroyPipelineLayout.?(
            device.device,
            pipeline_layout,
            null
        );

        var render_pass = try create_render_pass(device);
        errdefer Device.vkDestroyRenderPass.?(device.device, render_pass, null);

        var pipeline = try create_pipeline(
            device,
            descriptor_layouts,
            &vshader,
            &fshader,
            pipeline_layout,
            render_pass
        );
        errdefer Device.vkDestroyPipeline.?(device.device, pipeline, null);

        return Pass {
            .device = device,
            .command_pool = command_pool,
            .uniform_memory = uniform_memory,
            .vshader = vshader,
            .fshader = fshader,
            .vertices = vertices,
            .indices = indices,
            .descriptor_layouts = descriptor_layouts,
            .descriptor_pool = descriptor_pool,
            .uniforms = uniforms,
            .pipeline_layout = pipeline_layout,
            .render_pass = render_pass,
            .pipeline = pipeline
        };
    }

    pub fn deinit(self: *const Pass) void {
        Device.vkDestroyPipeline.?(
            self.device.device,
            self.pipeline,
            null
        );

        Device.vkDestroyRenderPass.?(
            self.device.device,
            self.render_pass,
            null
        );
        Device.vkDestroyPipelineLayout.?(
                self.device.device,
                self.pipeline_layout,
                null
        );

        if (self.uniform_memory) |um| {
            for (self.uniforms) |u| u.deinit();
            dealloc(self.uniforms.ptr);
            um.deinit();
        }

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

    for (layouts) |*layout, i| {
        const result = Device.vkCreateDescriptorSetLayout.?(
            device.device,
            descriptor_layout_info,
            null,
            layout
        );
        if (result != c.VkResult.VK_SUCCESS) {
            var ii = i;
            while (ii != 0) : (ii -= 1) {
                Device.vkDestroyDescriptorSetLayout.?(
                    device.device,
                    layouts[ii - 1],
                    null
                );
            }
            return error.BadDescriptorSetLayout;
        }
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

fn create_uniform_buffers(memory: *Memory) ![]Buffer {
    var uniforms = try alloc(Buffer, memory.device.swapchain_images.len);
    errdefer dealloc(uniforms.ptr);

    for (uniforms) |*u, i| {
        u.* = memory.create_buffer(
            16,
            c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            @sizeOf(Uniforms)
        ) catch |err| {
            var ii = i;
            while (ii != 0) : (ii -= 1) {
                uniforms[ii - 1].deinit();
            }

            return err;
        };
    }

    return uniforms;
}

fn create_pipeline_layout(
    device: *const Device,
    descriptor_layouts: []const c.VkDescriptorSetLayout
) !c.VkPipelineLayout {
    const create_info = c.VkPipelineLayoutCreateInfo {
        .sType =
            c.VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .setLayoutCount = @intCast(u32, descriptor_layouts.len),
        .pSetLayouts = descriptor_layouts.ptr,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null
    };

    var layout: c.VkPipelineLayout = undefined;
    const result = Device.vkCreatePipelineLayout.?(
        device.device,
        &create_info,
        null,
        &layout
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadPipelineLayout;

    return layout;
}

fn create_render_pass(device: *const Device) !c.VkRenderPass {
    const dependency = c.VkSubpassDependency {
        .dependencyFlags = 0,
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .srcAccessMask = 0,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT
    };
    const attachment = c.VkAttachmentDescription {
        .flags = 0,
        .format = device.surface_format.format,
        .samples = c.VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
    };
    const reference = c.VkAttachmentReference {
        .attachment = 0,
        .layout = c.VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
    };
    const subpass = c.VkSubpassDescription {
        .flags = 0,
        .pipelineBindPoint =
            c.VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &reference,
        .inputAttachmentCount = 0,
        .pInputAttachments = null,
        .pDepthStencilAttachment = null,
        .pResolveAttachments = null,
        .preserveAttachmentCount = 0,
        .pPreserveAttachments = null
    };
    const create_info = c.VkRenderPassCreateInfo {
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .attachmentCount = 1,
        .pAttachments = &attachment,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 1,
        .pDependencies = &dependency,
    };

    var render_pass: c.VkRenderPass = undefined;
    const result = Device.vkCreateRenderPass.?(
        device.device,
        &create_info,
        null,
        &render_pass
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadRenderPass;

    return render_pass;
}

fn generate_vertex_info(
    src_bindings: []const Binding,
    out_attrs: []c.VkVertexInputAttributeDescription,
    out_bindings: *c.VkVertexInputBindingDescription
) !void {
    if (src_bindings.len > out_attrs.len) return error.TooManyBindings;

    // TODO: Eventually we need to iterating over a double slice of bindings

    var stride: u32 = 0;
    for (src_bindings) |binding| {
        stride += switch (binding) {
            .Vec3 => @as(u32, @sizeOf(f32)) * 3,
            else => return error.NotImplemented
        };
    }
    out_bindings.* = c.VkVertexInputBindingDescription {
        .binding = 0,
        .stride = stride,
        .inputRate = c.VkVertexInputRate.VK_VERTEX_INPUT_RATE_VERTEX,
    };

    var offset: u32 = 0;
    for (src_bindings) |binding, i| {
        switch (binding) {
            .Vec3 => {
                out_attrs[i] = c.VkVertexInputAttributeDescription {
                    .location = @intCast(u32, i),
                    .binding = 0,
                    .format = c.VkFormat.VK_FORMAT_R32G32B32_SFLOAT,
                    .offset = offset
                };

                offset += @sizeOf(f32) * 3;
            },

            else => return error.NotImplemented
        }
    }
}

fn create_pipeline(
    device: *Device,
    descriptor_layouts: []c.VkDescriptorSetLayout,
    vshader: *const Shader,
    fshader: *const Shader,
    pipeline_layout: c.VkPipelineLayout,
    render_pass: c.VkRenderPass
) !c.VkPipeline {
    const shader_info = [_]c.VkPipelineShaderStageCreateInfo {
        c.VkPipelineShaderStageCreateInfo {
            .sType = c.VkStructureType
                .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .stage = c.VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT,
            .module = vshader.shader,
            .pName = "main",
            .pSpecializationInfo = null
        },
        c.VkPipelineShaderStageCreateInfo {
            .sType = c.VkStructureType
                .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .stage = c.VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
            .module = fshader.shader,
            .pName = "main",
            .pSpecializationInfo = null
        }
    };

    // TODO: This needs to be reworked to allow multiple bindings
    const MAX_ATTRS = 16;
    const MAX_BINDINGS = 16;
    const n_attrs: u32 = @intCast(u32, vshader.bindings.?.len);
    const n_bindings: u32 = 1;
    var attrs: [MAX_ATTRS]c.VkVertexInputAttributeDescription = undefined;
    var bindings: [MAX_BINDINGS]c.VkVertexInputBindingDescription = undefined;
    try generate_vertex_info(
        vshader.bindings.?,
        &attrs,
        &bindings[0],
    );
    const vertex_info = c.VkPipelineVertexInputStateCreateInfo {
        .sType = c.VkStructureType
            .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .vertexBindingDescriptionCount = n_bindings,
        .pVertexBindingDescriptions = &bindings,
        .vertexAttributeDescriptionCount = n_attrs,
        .pVertexAttributeDescriptions = &attrs
    };

    const assembly_info = c.VkPipelineInputAssemblyStateCreateInfo {
        .sType = c.VkStructureType
            .VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .topology = c.VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE
    };

    const viewport = c.VkViewport {
        .x = 0,
        .y = 0,
        .width = @intToFloat(f32, device.swap_extent.width),
        .height = @intToFloat(f32, device.swap_extent.height),
        .minDepth = 0,
        .maxDepth = 1,
    };
    const scissor = c.VkRect2D {
        .offset = c.VkOffset2D { .x = 0, .y = 0 },
        .extent = device.swap_extent
    };
    const viewport_info = c.VkPipelineViewportStateCreateInfo {
        .sType = c.VkStructureType
            .VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .viewportCount = 1,
        .pViewports = &viewport,
        .scissorCount = 1,
        .pScissors = &scissor
    };

    const raster_info = c.VkPipelineRasterizationStateCreateInfo {
        .sType = c.VkStructureType
            .VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .depthClampEnable = c.VK_FALSE,
        .rasterizerDiscardEnable = c.VK_FALSE,
        .polygonMode = c.VkPolygonMode.VK_POLYGON_MODE_FILL,
        .cullMode = c.VK_CULL_MODE_NONE,
        .frontFace = c.VkFrontFace.VK_FRONT_FACE_COUNTER_CLOCKWISE,
        .depthBiasEnable = c.VK_FALSE,
        .depthBiasClamp = 0,
        .depthBiasSlopeFactor = 0,
        .depthBiasConstantFactor = 0,
        .lineWidth = 1.0
    };

    const multisample_info = c.VkPipelineMultisampleStateCreateInfo {
        .sType = c.VkStructureType
            .VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .rasterizationSamples = c.VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
        .sampleShadingEnable = c.VK_FALSE,
        .minSampleShading = 1,
        .pSampleMask = null,
        .alphaToCoverageEnable = c.VK_FALSE,
        .alphaToOneEnable = c.VK_FALSE
    };

    const depth_info = c.VkPipelineDepthStencilStateCreateInfo {
        .sType = c.VkStructureType
            .VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .depthTestEnable = c.VK_FALSE,
        .depthWriteEnable = c.VK_FALSE,
        .depthBoundsTestEnable = c.VK_FALSE,
        .stencilTestEnable = c.VK_FALSE,
        .minDepthBounds = 0,
        .maxDepthBounds = 0,
        .depthCompareOp = c.VkCompareOp.VK_COMPARE_OP_NEVER,
        .front = c.VkStencilOpState {
            .failOp = c.VkStencilOp.VK_STENCIL_OP_KEEP,
            .passOp = c.VkStencilOp.VK_STENCIL_OP_KEEP,
            .depthFailOp = c.VkStencilOp.VK_STENCIL_OP_KEEP,
            .compareOp = c.VkCompareOp.VK_COMPARE_OP_NEVER,
            .compareMask = 0,
            .writeMask = 0,
            .reference = 0
        },
        .back = c.VkStencilOpState {
            .failOp = c.VkStencilOp.VK_STENCIL_OP_KEEP,
            .passOp = c.VkStencilOp.VK_STENCIL_OP_KEEP,
            .depthFailOp = c.VkStencilOp.VK_STENCIL_OP_KEEP,
            .compareOp = c.VkCompareOp.VK_COMPARE_OP_NEVER,
            .compareMask = 0,
            .writeMask = 0,
            .reference = 0
        },
    };

    const color_attachment = c.VkPipelineColorBlendAttachmentState {
        .blendEnable = c.VK_FALSE,
        .colorWriteMask =
            c.VK_COLOR_COMPONENT_R_BIT
            | c.VK_COLOR_COMPONENT_G_BIT
            | c.VK_COLOR_COMPONENT_B_BIT
            | c.VK_COLOR_COMPONENT_A_BIT,
        .srcColorBlendFactor = c.VkBlendFactor.VK_BLEND_FACTOR_ZERO,
        .dstColorBlendFactor = c.VkBlendFactor.VK_BLEND_FACTOR_ZERO,
        .colorBlendOp = c.VkBlendOp.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VkBlendFactor.VK_BLEND_FACTOR_ZERO,
        .dstAlphaBlendFactor = c.VkBlendFactor.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.VkBlendOp.VK_BLEND_OP_ADD
        
    };
    const color_info = c.VkPipelineColorBlendStateCreateInfo {
        .sType = c.VkStructureType
            .VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VkLogicOp.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &color_attachment,
        .blendConstants = [_]f32 { 0, 0, 0, 0 },
    };

    const dynamic_info = c.VkPipelineDynamicStateCreateInfo {
        .sType = c.VkStructureType
            .VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .dynamicStateCount = 0,
        .pDynamicStates = null
    };

    const graphics_pipeline = c.VkGraphicsPipelineCreateInfo {
        .sType =
            c.VkStructureType.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stageCount = shader_info.len,        // TODO: Don't hardcode this
        .pStages = &shader_info,
        .pVertexInputState = &vertex_info,
        .pInputAssemblyState = &assembly_info,
        .pViewportState = &viewport_info,
        .pRasterizationState = &raster_info,
        .pMultisampleState = &multisample_info,
        .pDepthStencilState = &depth_info,
        .pColorBlendState = &color_info,
        .pDynamicState = &dynamic_info,
        .pTessellationState = null,
        .layout = pipeline_layout,
        .renderPass = render_pass,
        .subpass = 0,
        .basePipelineHandle = null,
        .basePipelineIndex = -1
    };

    var pipeline: c.VkPipeline = undefined;
    const result = Device.vkCreateGraphicsPipelines.?(
        device.device,
        null,
        1,
        &graphics_pipeline,
        null,
        &pipeline
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadGraphicsPipeline;

    return pipeline;
}
