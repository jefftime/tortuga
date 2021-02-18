const Builder = @import("std").build.Builder;
const Pkg = @import("std").build.Pkg;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    const asan_enabled =
        b.option(bool, "asan", "Link with libasan") orelse false;

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const c_pkg = Pkg {
        .name = "c",
        .path = "./src/c/c.zig"
    };
    const mem_pkg = Pkg {
        .name = "mem",
        .path = "./src/mem/mem.zig",
        .dependencies = &[_]Pkg {c_pkg}
    };
    const window_pkg = Pkg {
        .name = "window",
        .path = "./src/window/window.zig",
        .dependencies = &[_]Pkg {c_pkg, mem_pkg}
    };
    const render_pkg = Pkg {
        .name = "render",
        .path = "./src/render/render.zig",
        .dependencies = &[_]Pkg {c_pkg, window_pkg, mem_pkg}
    };
    const util_pkg = Pkg {
        .name = "util",
        .path = "./src/util/util.zig",
        .dependencies = &[_]Pkg {c_pkg, mem_pkg}
    };

    const exe = b.addExecutable("tortuga", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addIncludeDir("/usr/include");
    exe.addLibPath("/usr/lib/x86_64-linux-gnu");
    exe.addPackage(c_pkg);
    exe.addPackage(mem_pkg);
    exe.addPackage(window_pkg);
    exe.addPackage(render_pkg);
    exe.addPackage(util_pkg);
    exe.linkLibC();
    exe.linkSystemLibrary("xcb");
    exe.linkSystemLibrary("xcb-xfixes");
    if (builtin.os.tag == .linux) {
        exe.linkSystemLibrary("dl");
    }

    if (mode == .Debug and asan_enabled) {
        // For some reason exe.linkSystemLibrary("asan") doesn't work :/
        exe.addObjectFile("/usr/lib/x86_64-linux-gnu/libasan.so.5");
    }

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const shader_cmd = b.addSystemCommand(&[_][]const u8 {
        "glslangValidator",
        "-V",
        "default.frag",
        "default.vert"
    });
    shader_cmd.cwd = "./shaders";
    const shader_step = b.step("shaders", "Build the shaders");
    shader_step.dependOn(&shader_cmd.step);
}
