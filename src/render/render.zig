pub const Render = @This();
pub const Context = @import("context.zig").Context;
const device = @import("device.zig");
pub const DeviceBuilder = device.DeviceBuilder;
pub const Device = device.Device;

const pass = @import("pass.zig");
pub const PassBuilder = pass.PassBuilder;
pub const Pass = pass.Pass;

const binding = @import("binding.zig");
pub const Binding = binding.Binding;

const shader = @import("shader.zig");
pub const ShaderKind = shader.ShaderKing;
pub const Shader = shader.Shader;

