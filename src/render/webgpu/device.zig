const std = @import("std");
usingnamespace @import("../../c.zig");
usingnamespace @import("../../window.zig");

fn wgpu_log(
    level: c.WGPULogLevel,
    msg: [*c]const u8
) callconv(.C) void {
    std.log.warn("{s}", .{msg});
}

pub const Device = struct {
    surface: c.WGPUSurface,
    device: c.WGPUDevice,

    pub fn init(self: *Device, window: *Window) !void {
        c.wgpuSetLogCallback(wgpu_log);
        c.wgpuSetLogLevel(
            @intToEnum(c.WGPULogLevel, c.WGPULogLevel_Warn)
        );

        const surface = c.wgpuInstanceCreateSurface(
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
        var shader = c.wgpuDeviceCreateShaderModule(device.device, &module_descriptor);

        self.* = Device {
            .surface = surface,
            .device = device
        };
    }
};

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
