const Builder = @import("std").build.Builder;
const Pkg = @import("std").build.Pkg;
const builtin = @import("builtin");

const RenderBackend = enum { webgpu, vulkan };

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

    const exe = b.addExecutable("tortuga", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibC();
    exe.addIncludeDir("./include");
    exe.addLibPath("./lib");

    const render_backend = b.option(
        RenderBackend,
        "render_backend",
        "Configure rendering engine (webgpu, vulkan)"
    ) orelse .webgpu;

    switch (render_backend) {
        .webgpu => {
            exe.addLibPath("/usr/lib/gcc/x86_64-linux-gnu/8");
            exe.linkSystemLibrary("wgpu_native");
            exe.linkSystemLibrary("gcc_s");
        },
        else => {}
    }

    exe.addBuildOption(RenderBackend, "render_backend", render_backend);

    if (builtin.os.tag == .linux) {
        exe.linkSystemLibrary("dl");
        exe.linkSystemLibrary("rt");
        exe.linkSystemLibrary("m");
        exe.linkSystemLibrary("xcb");
        exe.linkSystemLibrary("xcb-xfixes");
        exe.linkSystemLibrary("X11");
        exe.linkSystemLibrary("X11-xcb");
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
