const c = @import("c").c;
const std = @import("std");
const Device = @import("device.zig").Device;
const Binding = @import("binding.zig").Binding;
const memory_zig = @import("memory.zig");
const Buffer = memory_zig.Buffer;
const MemoryUsage = memory_zig.MemoryUsage;
const Memory = memory_zig.Memory;
const mem = @import("mem");
const alloc = mem.alloc;
const dealloc = mem.dealloc;

pub const ShaderGroup = struct {
    device: *const Device,
    uniform_memory: *Memory,
    uniform_size: usize,
    uniforms: []Buffer,
    bindings: []c.VkVertexInputBindingDescription,
    attrs: []c.VkVertexInputAttributeDescription,
    // TODO: Compute, tessellation, geometry, etc. shaders
    vertex_shader: c.VkShaderModule,
    fragment_shader: c.VkShaderModule,
    descriptor_layouts: []c.VkDescriptorSetLayout,
    descriptor_sets: []c.VkDescriptorSet,
    descriptor_pool: c.VkDescriptorPool,

    pub fn init(
        device: *const Device,
        uniform_memory: *Memory,
        comptime uniform_type: type,
        input_bindings: ?[]const []const Binding,
        vertex_shader: c.VkShaderModule,
        fragment_shader: c.VkShaderModule
    ) !ShaderGroup {
        var attrs: []c.VkVertexInputAttributeDescription = undefined;
        var bindings: []c.VkVertexInputBindingDescription = undefined;
        try setup_bindings(input_bindings, &attrs, &bindings);

        var descriptor_layouts = try create_descriptor_layouts(device);
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

        var descriptor_sets = try create_descriptor_sets(
            device,
            descriptor_pool,
            descriptor_layouts
        );
        errdefer {
            _ = Device.vkFreeDescriptorSets.?(
                device.device,
                descriptor_pool,
                @intCast(u32, descriptor_sets.len),
                descriptor_sets.ptr
            );
            dealloc(descriptor_sets.ptr);
        }

        const uniform_size = @sizeOf(uniform_type);
        var uniforms = try alloc(Buffer, device.swapchain_images.len);
        errdefer dealloc(uniforms.ptr);

        for (uniforms) |*u, i| {
            u.* = uniform_memory.create_buffer(
                .Cpu,
                16,
                MemoryUsage.Uniform.value(),
                uniform_size
            ) catch |err| {
                var ii = i;
                while (ii > 0) : (ii -= 1) uniforms[ii - 1].deinit();

                return err;
            };
        }

        return ShaderGroup {
            .device = device,
            .uniform_memory = uniform_memory,
            .uniform_size = uniform_size,
            .uniforms = uniforms,
            .attrs = attrs,
            .bindings = bindings,
            .vertex_shader = vertex_shader,
            .fragment_shader = fragment_shader,
            .descriptor_layouts = descriptor_layouts,
            .descriptor_sets = descriptor_sets,
            .descriptor_pool = descriptor_pool,
        };
    }

    pub fn deinit(self: *const ShaderGroup) void {
        for (self.uniforms) |u| u.deinit();
        dealloc(self.uniforms.ptr);

        _ = Device.vkFreeDescriptorSets.?(
            self.device.device,
            self.descriptor_pool,
            @intCast(u32, self.descriptor_sets.len),
            self.descriptor_sets.ptr
        );
        dealloc(self.descriptor_sets.ptr);

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

        dealloc(self.attrs.ptr);
        dealloc(self.bindings.ptr);
        Device.vkDestroyShaderModule.?(
            self.device.device,
            self.vertex_shader,
            null
        );
        Device.vkDestroyShaderModule.?(
            self.device.device,
            self.fragment_shader,
            null
        );
    }
};

fn setup_bindings(
    input_bindings: ?[]const []const Binding,
    attrs: *[]c.VkVertexInputAttributeDescription,
    bindings: *[]c.VkVertexInputBindingDescription
) !void {
    if (input_bindings) |in_bindings| {
        var total_attrs: usize = 0;
        for (in_bindings) |b| total_attrs += b.len;
        attrs.* = try alloc(
            c.VkVertexInputAttributeDescription,
            total_attrs
        );
        errdefer dealloc(attrs.*.ptr);

        bindings.* = try alloc(
            c.VkVertexInputBindingDescription,
            in_bindings.len
        );
        errdefer dealloc(bindings.*.ptr);

        var cur_attr: usize = 0;
        var cur_location: u32 = 0;
        for (in_bindings) |binding, i| {
            var offset: u32 = 0;
            for (binding) |attribute| {
                switch (attribute) {
                    .Float32 => {
                        const T = c.VkVertexInputAttributeDescription;
                        attrs.*[cur_attr] = T {
                            .location = cur_location,
                            .binding = @intCast(u32, i),
                            .format = c.VkFormat.VK_FORMAT_R32_SFLOAT,
                            .offset = offset
                        };
                        cur_attr += 1;
                        cur_location += 1;
                    },

                    .Vec3 => {
                        const T = c.VkVertexInputAttributeDescription;
                        attrs.*[cur_attr] = T {
                            .location = cur_location,
                            .binding = @intCast(u32, i),
                            .format = c.VkFormat.VK_FORMAT_R32G32B32_SFLOAT,
                            .offset = offset
                        };
                        cur_attr += 1;
                        cur_location += 1;
                    },

                    else => return error.NotImplemented
                }

                offset += attribute.width();
            }


            bindings.*[i] = c.VkVertexInputBindingDescription {
                .binding = @intCast(u32, i),
                .stride = offset,
                .inputRate = c.VkVertexInputRate.VK_VERTEX_INPUT_RATE_VERTEX,
            };
        }
    }
}

fn create_descriptor_layouts(device: *const Device) ![]c.VkDescriptorSetLayout {
    const T = c.VkDescriptorSetLayoutBinding;
    const descriptor_layout_bindings: []const T = &[_]T {
        T {
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

    var layouts = try alloc(
        c.VkDescriptorSetLayout,
        device.swapchain_images.len
    );
    errdefer dealloc(layouts.ptr);

    for (layouts) |*layout, i| {
        const result = Device.vkCreateDescriptorSetLayout.?(
            device.device,
            &descriptor_layout_info,
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
        .flags = c.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
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

fn create_descriptor_sets(
    device: *const Device,
    descriptor_pool: c.VkDescriptorPool,
    descriptor_layouts: []const c.VkDescriptorSetLayout
) ![]c.VkDescriptorSet {
    var sets = try alloc(c.VkDescriptorSet, descriptor_layouts.len);
    errdefer dealloc(sets.ptr);

    const alloc_info = c.VkDescriptorSetAllocateInfo {
        .sType = c.VkStructureType
            .VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .pNext = null,
        .descriptorPool = descriptor_pool,
        .descriptorSetCount = @intCast(u32, descriptor_layouts.len),
        .pSetLayouts = descriptor_layouts.ptr
    };

    const result = Device.vkAllocateDescriptorSets.?(
        device.device,
        &alloc_info,
        sets.ptr
    );
    if (result != c.VkResult.VK_SUCCESS) return error.BadDescriptionSet;

    return sets;
}

