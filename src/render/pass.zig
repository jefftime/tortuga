const std = @import("std");
const c = @import("c").c;
const Device = @import("device.zig").Device;
const memory_zig = @import("memory.zig");
const Memory = memory_zig.Memory;
const Buffer = memory_zig.Buffer;
const Mesh = @import("mesh.zig").Mesh;
const binding_zig = @import("binding.zig");
const Binding = binding_zig.Binding;
const attribute_zig = @import("attribute.zig");
const ShaderGroup = @import("shader.zig").ShaderGroup;
const mem = @import("mem");
const new = mem.new;
const alloc = mem.alloc;
const dealloc = mem.dealloc;

pub const PassToken = struct {
    image_index: u32
};

pub const Pass = struct {
    device: *Device,
    shader: *const ShaderGroup,
    pipeline_layout: c.VkPipelineLayout,
    render_pass: c.VkRenderPass,
    pipeline: c.VkPipeline,
    image_views: []c.VkImageView,
    framebuffers: []c.VkFramebuffer,
    command_pool: c.VkCommandPool, // TODO: Need pool per thread
    command_buffers: []c.VkCommandBuffer,

    pub fn init(device: *Device, shader: *const ShaderGroup) !Pass {
        var pipeline_layout = try create_pipeline_layout(
            device,
            shader
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
            shader,
            pipeline_layout,
            render_pass
        );
        errdefer Device.vkDestroyPipeline.?(device.device, pipeline, null);

        var image_views = try create_image_views(device);
        errdefer {
            for (image_views) |image| Device.vkDestroyImageView.?(
                device.device,
                image,
                null
            );
            dealloc(image_views.ptr);
        }

        var framebuffers = try create_framebuffers(
            device,
            render_pass,
            image_views
        );
        errdefer {
            for (framebuffers) |fb| Device.vkDestroyFramebuffer.?(
                device.device,
                fb,
                null
            );
            dealloc(framebuffers.ptr);
        }

        var command_pool = try create_command_pool(device);
        const command_buffers = try create_command_buffers(
            device,
            command_pool
        );

        return Pass {
            .device = device,
            .shader = shader,
            .pipeline_layout = pipeline_layout,
            .render_pass = render_pass,
            .pipeline = pipeline,
            .image_views = image_views,
            .framebuffers = framebuffers,
            .command_pool = command_pool,
            .command_buffers = command_buffers
        };
    }

    pub fn deinit(self: *const Pass) void {
        for (self.framebuffers) |fb| Device.vkDestroyFramebuffer.?(
            self.device.device,
            fb,
            null
        );
        dealloc(self.framebuffers.ptr);

        for (self.image_views) |image| Device.vkDestroyImageView.?(
            self.device.device,
            image,
            null
        );
        dealloc(self.image_views.ptr);

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

        Device.vkFreeCommandBuffers.?(
            self.device.device,
            self.command_pool,
            @intCast(u32, self.command_buffers.len),
            self.command_buffers.ptr
        );

        dealloc(self.command_buffers.ptr);
        Device.vkDestroyCommandPool.?(
            self.device.device,
            self.command_pool,
            null
        );
        std.log.info("destroying Pass", .{});
    }

    pub fn begin(self: *Pass) !PassToken {
        var image_index: u32 = undefined;
        var result = Device.vkAcquireNextImageKHR.?(
            self.device.device,
            self.device.swapchain.?,
            2_000_000_000,
            self.device.image_semaphore,
            null,
            &image_index
        );
        if (result == c.VkResult.VK_ERROR_OUT_OF_DATE_KHR) {
            var device = self.device;
            var shader = self.shader;

            self.deinit();

            try device.recreate_swapchain();
            self.* = try Pass.init(device, shader);
            return error.OutOfDatePass;
        }

        for (self.command_buffers) |buf| {
            result = Device.vkResetCommandBuffer.?(buf, 0);
            if (result != c.VkResult.VK_SUCCESS) {
                return error.BadCommandBufferReset;
            }
        }

        return PassToken { .image_index = image_index };
    }

    pub fn set_uniforms(self: *Pass, comptime T: type, data: *const T) !void {
        for (self.shader.uniforms) |*u| {
            try u.write(T, @ptrCast([*]const T, data)[0..1]);
            for (self.shader.descriptor_sets) |set, i| {
                const buffer_info = c.VkDescriptorBufferInfo {
                    .buffer = self.shader.uniforms[i].memory.buffer,
                    .offset = self.shader.uniforms[i].offset,
                    .range = @intCast(u32, self.shader.uniform_size)
                };

                const write_info = c.VkWriteDescriptorSet {
                    .sType = c.VkStructureType
                        .VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                    .pNext = null,
                    .dstSet = set,
                    .dstBinding = 0,
                    .dstArrayElement = 0,
                    .descriptorType = c.VkDescriptorType
                        .VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                    .descriptorCount = 1,
                    .pBufferInfo = &buffer_info,
                    .pImageInfo = null,
                    .pTexelBufferView = null
                };

                Device.vkUpdateDescriptorSets.?(
                    self.device.device,
                    1,
                    &write_info,
                    0,
                    null
                );
            }
        }
    }

    pub fn draw(
        self: *Pass,
        token: PassToken,
        mesh: *Mesh
    ) !void {
        const begin_info = c.VkCommandBufferBeginInfo {
            .sType =
                c.VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pNext = null,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pInheritanceInfo = null
        };

        var result = Device.vkBeginCommandBuffer.?(
            self.command_buffers[token.image_index],
            &begin_info
        );
        if (result != c.VkResult.VK_SUCCESS) {
            return error.BadCommandBufferBegin;
        }

        const clear_value = c.VkClearValue {
            .color = c.VkClearColorValue {
                .float32 = [_]f32 { 0.2, 0.1, 0.1, 0 }
            }
        };
        const render_info = c.VkRenderPassBeginInfo {
            .sType =
                c.VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .pNext = null,
            .renderPass = self.render_pass,
            .framebuffer = self.framebuffers[token.image_index],
            .renderArea = c.VkRect2D {
                .offset = c.VkOffset2D { .x = 0, .y = 0 },
                .extent = self.device.swap_extent
            },
            .clearValueCount = 1,
            .pClearValues = &clear_value
        };

        Device.vkCmdBeginRenderPass.?(
            self.command_buffers[token.image_index],
            &render_info,
            c.VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE
        );
        {
            Device.vkCmdBindPipeline.?(
                self.command_buffers[token.image_index],
                c.VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS,
                self.pipeline
            );
            Device.vkCmdBindDescriptorSets.?(
                self.command_buffers[token.image_index],
                c.VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS,
                self.pipeline_layout,
                0,
                1,
                &self.shader.descriptor_sets[token.image_index],
                0,
                null
            );
            const offsets = &[_]c.VkDeviceSize { mesh.vertices.offset };
            Device.vkCmdBindVertexBuffers.?(
                self.command_buffers[token.image_index],
                0,
                1,
                &mesh.vertices.memory.buffer,
                offsets
            );
            Device.vkCmdBindIndexBuffer.?(
                self.command_buffers[token.image_index],
                mesh.indices.memory.buffer,
                mesh.indices.offset,
                mesh.index_type
            );
            Device.vkCmdDrawIndexed.?(
                self.command_buffers[token.image_index],
                @intCast(u32, mesh.n_indices),
                1,
                0,
                0,
                0
            );
        }
        Device.vkCmdEndRenderPass.?(self.command_buffers[token.image_index]);
        result = Device.vkEndCommandBuffer.?(
            self.command_buffers[token.image_index]
        );
        if (result != c.VkResult.VK_SUCCESS) {
            return error.BadCommandBufferWrite;
        }
    }

    pub fn submit(self: *Pass, token: PassToken) !void {
        const wait_stages = &[_]c.VkPipelineStageFlags {
            c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT
        };
        const submit_info = c.VkSubmitInfo {
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .pNext = null,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &self.device.image_semaphore,
            .pWaitDstStageMask = wait_stages,
            .commandBufferCount = 1,
            .pCommandBuffers = &self.command_buffers[token.image_index],
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = &self.device.render_semaphore
        };
        const result = Device.vkQueueSubmit.?(
            self.device.graphics_queue,
            1,
            &submit_info,
            null
        );

        const out_of_date = result == c.VkResult.VK_ERROR_OUT_OF_DATE_KHR;
        const suboptimal = result == c.VkResult.VK_SUBOPTIMAL_KHR;
        if (out_of_date or suboptimal) {
            const device = self.device;
            const shader = self.shader;

            self.deinit();

            try device.recreate_swapchain();
            self.* = try Pass.init(device, shader);
            return error.OutOfDatePass;
        }

        const present_info = c.VkPresentInfoKHR {
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .pNext = null,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &self.device.render_semaphore,
            .swapchainCount = 1,
            .pSwapchains = &self.device.swapchain.?,
            .pImageIndices = &token.image_index,
            .pResults = null
        };
        _ = Device.vkQueuePresentKHR.?(
            self.device.present_queue,
            &present_info
        );
        _ = Device.vkQueueWaitIdle.?(self.device.present_queue);
    }
};


fn create_pipeline_layout(
    device: *const Device,
    shader: *const ShaderGroup
) !c.VkPipelineLayout {
    const create_info = c.VkPipelineLayoutCreateInfo {
        .sType =
            c.VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .setLayoutCount = @intCast(u32, shader.descriptor_layouts.len),
        .pSetLayouts = shader.descriptor_layouts.ptr,
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
        .stencilStoreOp =
            c.VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
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

fn create_pipeline(
    device: *Device,
    shader: *const ShaderGroup,
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
            .module = shader.vertex_shader,
            .pName = "main",
            .pSpecializationInfo = null
        },
        c.VkPipelineShaderStageCreateInfo {
            .sType = c.VkStructureType
                .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .stage = c.VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
            .module = shader.fragment_shader,
            .pName = "main",
            .pSpecializationInfo = null
        }
    };

    const vertex_info = c.VkPipelineVertexInputStateCreateInfo {
        .sType = c.VkStructureType
            .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .vertexBindingDescriptionCount = @intCast(u32, shader.bindings.len),
        .pVertexBindingDescriptions = shader.bindings.ptr,
        .vertexAttributeDescriptionCount = @intCast(u32, shader.attrs.len),
        .pVertexAttributeDescriptions = shader.attrs.ptr,
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

fn create_image_views(device: *const Device) ![]c.VkImageView {
    var image_views = try alloc(c.VkImageView, device.swapchain_images.len);
    for (device.swapchain_images) |image, i| {
        const create_info = c.VkImageViewCreateInfo {
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .image = image,
            .viewType = c.VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
            .format = device.surface_format.format,
            .components = c.VkComponentMapping {
                .r = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            .subresourceRange = c.VkImageSubresourceRange {
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1
            }
        };

        const result = Device.vkCreateImageView.?(
            device.device,
            &create_info,
            null,
            &image_views[i]
        );
        if (result != c.VkResult.VK_SUCCESS) {
            var ii = i;
            while (ii != 0) : (ii -= 1) Device.vkDestroyImageView.?(
                device.device,
                image_views[ii - 1],
                null
            );
            return error.BadImageView;
        }
    }

    return image_views;
}

fn create_framebuffers(
    device: *const Device,
    render_pass: c.VkRenderPass,
    image_views: []const c.VkImageView
) ![]c.VkFramebuffer {
    var framebuffers = try alloc(c.VkFramebuffer, image_views.len);
    errdefer dealloc(framebuffers.ptr);

    for (image_views) |image, i| {
        const create_info = c.VkFramebufferCreateInfo {
            .sType =
                c.VkStructureType.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .renderPass = render_pass,
            .attachmentCount = 1,
            .pAttachments = &image,
            .width = device.swap_extent.width,
            .height = device.swap_extent.height,
            .layers = 1
        };

        const result = Device.vkCreateFramebuffer.?(
            device.device,
            &create_info,
            null,
            &framebuffers[i]
        );
        if (result != c.VkResult.VK_SUCCESS) {
            var ii = i;
            while (ii > 0) : (ii -= 1) Device.vkDestroyFramebuffer.?(
                device.device,
                framebuffers[ii - 1],
                null
            );
            return error.BadFramebuffer;
        }
    }

    return framebuffers;
}

fn create_command_pool(device: *const Device) !c.VkCommandPool {
    const create_info = c.VkCommandPoolCreateInfo {
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .pNext = null,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
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

fn create_command_buffers(
    device: *const Device,
    pool: c.VkCommandPool
) ![]c.VkCommandBuffer {
    var command_buffers = try alloc(
        c.VkCommandBuffer,
        device.swapchain_images.len
    );
    errdefer dealloc(command_buffers.ptr);

    const alloc_info = c.VkCommandBufferAllocateInfo {
        .sType =
            c.VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .pNext = null,
        .commandPool = pool,
        .level = c.VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = @intCast(u32, device.swapchain_images.len)
    };
    const result = Device.vkAllocateCommandBuffers.?(
        device.device,
        &alloc_info,
        command_buffers.ptr
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadCommandBuffers;

    return command_buffers;
}

