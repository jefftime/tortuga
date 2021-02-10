pub const Binding = enum(u8) {
    Float32,
    Float64,
    Vec2,
    Vec3,
    Vec4,
    Mat3,
    Mat4,

    pub fn width(self: BindingType) u8 {
        return switch (self) {
            .Float32 => 4,
            .Float64 => 8,
            .Vec2 => 8,
            .Vec3 => 12,
            .Vec4 => 16,
            .Mat3 => 24,
            .Mat4 => 64,
        };
    }
};
