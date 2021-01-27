pub const std = @import("std");
pub const c = @import("c").c;
pub const Context = @import("context.zig").Context;

pub const Device = struct {
    context: *const Context,
    physical_device: usize,     // Index into context.devices

    pub fn init(context: *const Context, device_id: usize) !Device {
        var props: c.VkPhysicalDeviceProperties = undefined;
        var features: c.VkPhysicalDeviceFeatures = undefined;
        var mem_props: c.VkPhysicalDeviceMemoryProperties = undefined;
        Context.vkGetPhysicalDeviceProperties.?(
            context.devices[device_id],
            &props
        );
        Context.vkGetPhysicalDeviceFeatures.?(
            context.devices[device_id],
            &features
        );

        std.log.info("selecting device `{}`", .{props.deviceName});

        return Device {
            .context = context,
            .physical_device = device_id
        };
    }

    pub fn deinit(self: *const Device) void {
        std.log.info("destroy Device", .{});
    }
};
