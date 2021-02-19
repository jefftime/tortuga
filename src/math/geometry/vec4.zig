pub const Vec4 = extern struct {
    x: f32 align(16),
    y: f32,
    z: f32,
    w: f32,

    pub fn add(lhs: *const Vec4, rhs: *const Vec4) Vec4 {
        return Vec4 {
            .x = lhs.x + rhs.x,
            .y = lhs.y + rhs.y,
            .z = lhs.z + rhs.z,
            .w = lhs.w + rhs.w
        };
    }

    pub fn sub(lhs: *const Vec4, rhs: *const Vec4) Vec4 {
        return Vec4 {
            .x = lhs.x - rhs.x,
            .y = lhs.y - rhs.y,
            .z = lhs.z - rhs.z,
            .w = lhs.w - rhs.w
        };
    }

    pub fn mul(lhs: *const Vec4, rhs: f32) Vec4 {
        return Vec4 {
            .x = lhs.x * rhs,
            .y = lhs.y * rhs,
            .z = lhs.z * rhs,
            .w = lhs.w * rhs
        };
    }

    pub fn magnitude(lhs: *const Vec4) f32 {
        return @sqrt(lhs.x + lhs.y + lhs.z + lhs.w);
    }

    pub fn normalize(lhs: *Vec4) void {
        const magnitude = lhs.magnitude();
        lhs.x.* = lhs.x / magnitude;
        lhs.y.* = lhs.y / magnitude;
        lhs.z.* = lhs.z / magnitude;
        lhs.w.* = lhs.w / magnitude;
    }

    pub fn normal(lhs: *const Vec4) Vec4 {
        var result = lhs.*;
        result.normalize();
        return result;
    }

    pub fn cross(lhs: *const Vec4, rhs: *const Vec4) Vec4 {
        const i = (lhs.y * rhs.z) - (lhs.z * rhs.y);
        const j = -((lhs.x * rhs.z) - (lhs.z * rhs.x));
        const k = (lhs.x * rhs.y - lhs.y * rhs.x);
        return Vec4 {
            .x = i,
            .y = j,
            .z = k,
            .w = 1
        };
    }
};
