usingnamespace @import("../c.zig");

pub const ShaderAttribute = struct {
    name: []const u8
};

pub const Shader = struct {
    handle: c.GLuint
};
