const std = @import("std");

usingnamespace @import("util.zig");
usingnamespace @import("window.zig");
usingnamespace @import("render.zig");
usingnamespace @import("math.zig");
usingnamespace @import("mem.zig");
usingnamespace @import("c.zig");

const backend = @import("build_options").render_backend;

fn request_adapter_callback(
    received: c.WGPUAdapter,
    userdata: ?*c_void
) callconv(.C) void {
    var data = @ptrCast(*const *c.WGPUAdapter, &userdata);
    data.*.* = received;
}

fn request_device_callback(
    received: c.WGPUDevice,
    userdata: ?*c_void
) callconv(.C) void {
    var data = @ptrCast(*const *c.WGPUDevice, &userdata);
    data.*.* = received;
}

fn wgpu_log(
    level: c.WGPULogLevel,
    msg: [*c]const u8
) callconv(.C) void {
    std.log.warn("{s}", .{msg});
}

pub fn main() anyerror!void {
    // TODO: parse args

    c.wgpuSetLogCallback(wgpu_log);
    c.wgpuSetLogLevel(@intToEnum(c.WGPULogLevel, c.WGPULogLevel_Warn));

    const width = 960;
    const height = 720;

    var window: Window = undefined;
    try window.init("Tortuga", width, height);
    defer window.deinit();

    window.show_cursor();

    var surface = c.wgpuInstanceCreateSurface(
        null,
        &c.WGPUSurfaceDescriptor {
            .label = null,
            .nextInChain = @ptrCast(
                *const c.WGPUChainedStruct,
                &c.WGPUSurfaceDescriptorFromXlib {
                    .chain = c.WGPUChainedStruct {
                        .next = null,
                        .sType = @intToEnum(
                            c.enum_WGPUSType,
                            c.WGPUSType_SurfaceDescriptorFromXlib
                        )
                    },
                    .display = window.display,
                    .window = window.window
                }
            )
        }
    );

    var adapter: c.WGPUAdapter = undefined;
    c.wgpuInstanceRequestAdapter(
        null,
        &c.WGPURequestAdapterOptions {
            .nextInChain = null,
            .compatibleSurface = surface
        },
        request_adapter_callback,
        @ptrCast(*c_void, &adapter)
    );

    var device: c.WGPUDevice = undefined;
    c.wgpuAdapterRequestDevice(
        adapter,
        &c.WGPUDeviceDescriptor { .nextInChain = null },
        request_device_callback,
        @ptrCast(*c_void, &device)
    );

    const shader_source = try read_file("shader.wgsl");
    const wgsl_descriptor = try new(c.WGPUShaderModuleWGSLDescriptor);
    defer dealloc(wgsl_descriptor);
    wgsl_descriptor.* = c.WGPUShaderModuleWGSLDescriptor {
        .chain = c.WGPUChainedStruct {
            .next = null,
            .sType = @intToEnum(
                c.WGPUSType,
                c.WGPUSType_ShaderModuleWGSLDescriptor
            )
        },
        .source = shader_source.ptr
    };

    var module_descriptor = c.WGPUShaderModuleDescriptor {
        .nextInChain = @ptrCast(*const c.WGPUChainedStruct, wgsl_descriptor),
        .label = "shader.wgsl"
    };
    var shader = c.wgpuDeviceCreateShaderModule(device, &module_descriptor);

    const bind_group_layout = c.wgpuDeviceCreateBindGroupLayout(
        device,
        @ptrCast(
            [*c]const c.WGPUBindGroupLayoutDescriptor,
            &c.WGPUBindGroupLayoutDescriptor {
                .nextInChain = null,
                .label = "bind group layout",
                .entries = null,
                .entryCount = 0
            }
        )
    );
    const bind_group = c.wgpuDeviceCreateBindGroup(
        device,
        &c.WGPUBindGroupDescriptor {
            .nextInChain = null,
            .label = "bind group",
            .layout = bind_group_layout,
            .entries = null,
            .entryCount = 0
        }
    );
    const bind_group_layouts: []c.WGPUBindGroupLayout =
        &[_]c.WGPUBindGroupLayout { bind_group_layout };

    const pipeline_layout = c.wgpuDeviceCreatePipelineLayout(
        device,
        &c.WGPUPipelineLayoutDescriptor {
            .nextInChain = null,
            .label = "pipeline",
            .bindGroupLayouts = bind_group_layouts.ptr,
            .bindGroupLayoutCount = @intCast(u32, bind_group_layouts.len)
        }
    );
    const pipeline = c.wgpuDeviceCreateRenderPipeline(
        device,
        &c.WGPURenderPipelineDescriptor {
            .nextInChain = null,
            .label = "render pipeline",
            .layout = pipeline_layout,
            .vertex = c.WGPUVertexState {
                .nextInChain = null,
                .module = shader,
                .entryPoint = "vs_main",
                .bufferCount = 0,
                .buffers = null
            },
            .primitive = c.WGPUPrimitiveState {
                .nextInChain = null,
                .topology = @intToEnum(
                    c.WGPUPrimitiveTopology,
                    c.WGPUPrimitiveTopology_TriangleList
                ),
                .stripIndexFormat = @intToEnum(
                    c.WGPUIndexFormat,
                    c.WGPUIndexFormat_Undefined
                ),
                .frontFace = @intToEnum(
                    c.WGPUFrontFace,
                    c.WGPUFrontFace_CCW
                ),
                .cullMode = @intToEnum(
                    c.WGPUCullMode,
                    c.WGPUCullMode_None
                )
            },
            .multisample = c.WGPUMultisampleState {
                .nextInChain = null,
                .count = 1,
                .mask = ~@as(u32, 0),
                .alphaToCoverageEnabled = false
            },
            .fragment = &c.WGPUFragmentState {
                .nextInChain = null,
                .module = shader,
                .entryPoint = "fs_main",
                .targetCount = 1,
                .targets = &c.WGPUColorTargetState {
                    .nextInChain = null,
                    .format = @intToEnum(
                        c.WGPUTextureFormat,
                        c.WGPUTextureFormat_BGRA8Unorm
                    ),
                    .blend = &c.WGPUBlendState {
                        .color = c.WGPUBlendComponent {
                            .srcFactor = @intToEnum(
                                c.WGPUBlendFactor,
                                c.WGPUBlendFactor_One
                            ),
                            .dstFactor = @intToEnum(
                                c.WGPUBlendFactor,
                                c.WGPUBlendFactor_Zero
                            ),
                            .operation = @intToEnum(
                                c.WGPUBlendOperation,
                                c.WGPUBlendOperation_Add
                            )
                        },
                        .alpha = c.WGPUBlendComponent {
                            .srcFactor = @intToEnum(
                                c.WGPUBlendFactor,
                                c.WGPUBlendFactor_One
                            ),
                            .dstFactor = @intToEnum(
                                c.WGPUBlendFactor,
                                c.WGPUBlendFactor_Zero
                            ),
                            .operation = @intToEnum(
                                c.WGPUBlendOperation,
                                c.WGPUBlendOperation_Add
                            )
                        },
                    },
                    .writeMask = c.WGPUColorWriteMask_All
                }
            },
            .depthStencil = null
        }
    );

    var swapchain = c.wgpuDeviceCreateSwapChain(
        device,
        surface,
        &c.WGPUSwapChainDescriptor {
            .nextInChain = null,
            .label = "swapchain",
            .usage = c.WGPUTextureUsage_RenderAttachment,
            .format = @intToEnum(
                c.WGPUTextureFormat,
                c.WGPUTextureFormat_BGRA8Unorm
            ),
            .width = width,
            .height = height,
            .presentMode = @intToEnum(
                c.WGPUPresentMode,
                c.WGPUPresentMode_Fifo
            )
        }
    );

    while (true) {
        if (window.should_close()) break;

        var texture = c.wgpuSwapChainGetCurrentTextureView(swapchain) orelse {
            std.log.err("cannot acquire next swapchain texture", .{});
            return error.BadTexture;
        };

        var encoder = c.wgpuDeviceCreateCommandEncoder(
            device,
            &c.WGPUCommandEncoderDescriptor {
                .nextInChain = null,
                .label = "command encoder"
            }
        );

        var pass = c.wgpuCommandEncoderBeginRenderPass(
            encoder,
            &c.WGPURenderPassDescriptor {
                .nextInChain = null,
                .label = "render pass",
                .occlusionQuerySet = null,
                .colorAttachments = &c.WGPURenderPassColorAttachmentDescriptor {
                    .attachment = texture,
                    .resolveTarget = null,
                    .loadOp = @intToEnum(
                        c.WGPULoadOp,
                        c.WGPULoadOp_Clear
                    ),
                    .storeOp = @intToEnum(
                        c.WGPUStoreOp,
                        c.WGPUStoreOp_Store
                    ),
                    .clearColor = c.WGPUColor {
                        .r = 0.0,
                        .g = 1.0,
                        .b = 0.0,
                        .a = 1.0
                    }
                },
                .colorAttachmentCount = 1,
                .depthStencilAttachment = null
            }
        );

        c.wgpuRenderPassEncoderSetPipeline(pass, pipeline);
        c.wgpuRenderPassEncoderSetBindGroup(pass, 0, bind_group, 0, null);
        c.wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
        c.wgpuRenderPassEncoderEndPass(pass);

        var queue = c.wgpuDeviceGetQueue(device);
        var cmdbuf = c.wgpuCommandEncoderFinish(
            encoder,
            &c.WGPUCommandBufferDescriptor {
                .nextInChain = null,
                .label = "command buffer"
            }
        );
        c.wgpuQueueSubmit(queue, 1, &cmdbuf);
        c.wgpuSwapChainPresent(swapchain);

        window.update();
    }
}
