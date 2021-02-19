pub const Vec3 = extern struct {
    x: f32 align(16),
    y: f32,
    z: f32,

    pub fn add(lhs: *const Vec3, rhs: *const Vec3) Vec3 {
        return Vec3 {
            .x = lhs.x + rhs.x,
            .y = lhs.y + rhs.y,
            .z = lhs.z + rhs.z
        };
    }

    pub fn sub(lhs: *const Vec3, rhs: *const Vec3) Vec3 {
        return Vec3 {
            .x = lhs.x - rhs.x,
            .y = lhs.y - rhs.y,
            .z = lhs.z - rhs.z
        };
    }

    pub fn mul(lhs: *const Vec3, rhs: f32) Vec3 {
        return Vec3 {
            .x = lhs.x * rhs,
            .y = lhs.y * rhs,
            .z = lhs.z * rhs
        };
    }

    pub fn magnitude(lhs: *const Vec3) f32 {
        return @sqrt(lhs.x + lhs.y + lhs.z);
    }

    pub fn normalize(lhs: *Vec3) void {
        const magnitude = lhs.magnitude();
        lhs.x.* = lhs.x / magnitude;
        lhs.y.* = lhs.y / magnitude;
        lhs.z.* = lhs.z / magnitude;
    }

    pub fn normal(lhs: *const Vec3) Vec3 {
        var result = lhs.*;
        result.normalize();
        return result;
    }

    pub fn cross(lhs: *const Vec3, rhs: *const Vec3) Vec3 {
        const i = (lhs.y * rhs.z) - (lhs.z * rhs.y);
        const j = -((lhs.x * rhs.z) - (lhs.z * rhs.x));
        const k = (lhs.x * rhs.y - lhs.y * rhs.x);
        return Vec3 {
            .x = i,
            .y = j,
            .z = k
        };
    }
};
