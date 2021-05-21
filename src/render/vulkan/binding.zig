pub const Binding = enum(u8) {
    Float32,
    Float64,
    Vec2,
    Vec3,
    Vec4,
    Mat3,
    Mat4,

    pub fn width(self: *const Binding) u8 {
        return switch (self.*) {
            .Float32 => @sizeOf(f32),
            .Float64 => @sizeOf(f64),
            .Vec2 => @sizeOf(f32) * 2,
            .Vec3 => @sizeOf(f32) * 3,
            .Vec4 => @sizeOf(f32) * 4,
            .Mat3 => @sizeOf(f32) * 3 * 3,
            .Mat4 => @sizeOf(f32) * 4 * 4,
        };
    }
};
