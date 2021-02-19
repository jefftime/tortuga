pub const Vec4 = @import("vec4.zig").Vec4;

pub const Mat4 = extern struct {
    data: [16]f32 align(16),

    pub fn identity() Mat4 {
        return Mat4 {
            .data = [_]f32 {
                1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1
            }
        };
    }

    pub fn zeroed() Mat4 {
        return Mat4 {
            .data = [_]f32 {
                0, 0, 0, 0,
                0, 0, 0, 0,
                0, 0, 0, 0,
                0, 0, 0, 0
            }
        };
    }

    pub fn add(lhs: *const Mat4, rhs: *const Mat4) Mat4 {
        return Mat4 {
            .data = [_]f32 {
                lhs.data[0] + rhs.data[0],
                lhs.data[1] + rhs.data[1],
                lhs.data[2] + rhs.data[2],
                lhs.data[3] + rhs.data[3],
                lhs.data[4] + rhs.data[4],
                lhs.data[5] + rhs.data[5],
                lhs.data[6] + rhs.data[6],
                lhs.data[7] + rhs.data[7],
                lhs.data[8] + rhs.data[8],
                lhs.data[9] + rhs.data[9],
                lhs.data[10] + rhs.data[10],
                lhs.data[11] + rhs.data[11],
                lhs.data[12] + rhs.data[12],
                lhs.data[13] + rhs.data[13],
                lhs.data[14] + rhs.data[14],
                lhs.data[15] + rhs.data[15]
            }
        };
    }

    pub fn sub(lhs: *const Mat4, rhs: *const Mat4) Mat4 {
        return Mat4 {
            .data = [_]f32 {
                lhs.data[0] - rhs.data[0],
                lhs.data[1] - rhs.data[1],
                lhs.data[2] - rhs.data[2],
                lhs.data[3] - rhs.data[3],
                lhs.data[4] - rhs.data[4],
                lhs.data[5] - rhs.data[5],
                lhs.data[6] - rhs.data[6],
                lhs.data[7] - rhs.data[7],
                lhs.data[8] - rhs.data[8],
                lhs.data[9] - rhs.data[9],
                lhs.data[10] - rhs.data[10],
                lhs.data[11] - rhs.data[11],
                lhs.data[12] - rhs.data[12],
                lhs.data[13] - rhs.data[13],
                lhs.data[14] - rhs.data[14],
                lhs.data[15] - rhs.data[15]
            }
        };
    }

    pub fn mulm(lhs: *const Mat4, rhs: *const Mat4) Mat4 {
        const r11 =
            lhs.data[0] * rhs.data[0]
            + lhs.data[1] * rhs.data[4]
            + lhs.data[2] * rhs.data[8]
            + lhs.data[3] * rhs.data[12];
        const r12 =
            lhs.data[0] * rhs.data[1]
            + lhs.data[1] * rhs.data[5]
            + lhs.data[2] * rhs.data[9]
            + lhs.data[3] * rhs.data[13];
        const r13 =
            lhs.data[0] * rhs.data[2]
            + lhs.data[1] * rhs.data[6]
            + lhs.data[2] * rhs.data[10]
            + lhs.data[3] * rhs.data[14];
        const r14 =
            lhs.data[0] * rhs.data[3]
            + lhs.data[1] * rhs.data[4]
            + lhs.data[2] * rhs.data[11]
            + lhs.data[3] * rhs.data[15];
        const r21 =
            lhs.data[4] * rhs.data[0]
            + lhs.data[5] * rhs.data[4]
            + lhs.data[6] * rhs.data[8]
            + lhs.data[7] * rhs.data[12];
        const r22 =
            lhs.data[4] * rhs.data[1]
            + lhs.data[5] * rhs.data[5]
            + lhs.data[6] * rhs.data[9]
            + lhs.data[7] * rhs.data[13];
        const r23 =
            lhs.data[4] * rhs.data[2]
            + lhs.data[5] * rhs.data[6]
            + lhs.data[6] * rhs.data[10]
            + lhs.data[7] * rhs.data[14];
        const r24 =
            lhs.data[4] * rhs.data[3]
            + lhs.data[5] * rhs.data[4]
            + lhs.data[6] * rhs.data[11]
            + lhs.data[7] * rhs.data[15];
        const r31 =
            lhs.data[8] * rhs.data[0]
            + lhs.data[9] * rhs.data[4]
            + lhs.data[10] * rhs.data[8]
            + lhs.data[11] * rhs.data[12];
        const r32 =
            lhs.data[8] * rhs.data[1]
            + lhs.data[9] * rhs.data[5]
            + lhs.data[10] * rhs.data[9]
            + lhs.data[11] * rhs.data[13];
        const r33 =
            lhs.data[8] * rhs.data[2]
            + lhs.data[9] * rhs.data[6]
            + lhs.data[10] * rhs.data[10]
            + lhs.data[11] * rhs.data[14];
        const r34 =
            lhs.data[8] * rhs.data[3]
            + lhs.data[9] * rhs.data[4]
            + lhs.data[10] * rhs.data[11]
            + lhs.data[11] * rhs.data[15];
        const r41 =
            lhs.data[12] * rhs.data[0]
            + lhs.data[13] * rhs.data[4]
            + lhs.data[14] * rhs.data[8]
            + lhs.data[15] * rhs.data[12];
        const r42 =
            lhs.data[12] * rhs.data[1]
            + lhs.data[13] * rhs.data[5]
            + lhs.data[14] * rhs.data[9]
            + lhs.data[15] * rhs.data[13];
        const r43 =
            lhs.data[12] * rhs.data[2]
            + lhs.data[13] * rhs.data[6]
            + lhs.data[14] * rhs.data[10]
            + lhs.data[15] * rhs.data[14];
        const r44 =
            lhs.data[12] * rhs.data[3]
            + lhs.data[13] * rhs.data[4]
            + lhs.data[14] * rhs.data[11]
            + lhs.data[15] * rhs.data[15];
        return Mat4 {
            .data = [_]f32 {
                r11, r12, r13, r14,
                r21, r22, r23, r24,
                r31, r32, r33, r34,
                r41, r42, r43, r44
            }
        };
    }

    pub fn mulv(lhs: *const Mat4, rhs: *const Vec4) Vec4 {
        const x =
            lhs.data[0] * rhs.x
            + lhs.data[1] * rhs.y
            + lhs.data[2] * rhs.z
            + lhs.data[3] * rhs.w;
        const y =
            lhs.data[4] * rhs.x
            + lhs.data[5] * rhs.y
            + lhs.data[6] * rhs.z
            + lhs.data[7] * rhs.w;
        const z =
            lhs.data[8] * rhs.x
            + lhs.data[9] * rhs.y
            + lhs.data[10] * rhs.z
            + lhs.data[11] * rhs.w;
        const w =
            lhs.data[12] * rhs.x
            + lhs.data[13] * rhs.y
            + lhs.data[14] * rhs.z
            + lhs.data[15] * rhs.w;
        return Vec4 {
            .x = x,
            .y = y,
            .z = z,
            .w = w
        };
    }
};
