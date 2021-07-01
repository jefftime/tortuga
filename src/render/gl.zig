const std = @import("std");
usingnamespace @import("../c.zig");
usingnamespace @import("../window.zig");

pub const GlRenderer = struct {
    display: c.EGLDisplay,
    surface: c.EGLSurface,
    context: c.EGLContext,

    pub fn init(self: *GlRenderer, window: *Window) !void {
        if (c.eglBindAPI(c.EGL_OPENGL_API) != c.EGL_TRUE) {
            return error.BadBindApi;
        }

        const display_attrs = [_]c.EGLAttrib {
            c.EGL_NONE
        };
        const display = c.eglGetPlatformDisplay(
            c.EGL_PLATFORM_X11_EXT,
            @ptrCast(*c_void, window.display),
            display_attrs[0..display_attrs.len]
        );
        if (display == c.EGL_NO_DISPLAY) return error.BadDisplay;

        var major: c_int = undefined;
        var minor: c_int = undefined;
        var result = c.eglInitialize(display, &major, &minor);
        if (result != c.EGL_TRUE) return error.BadEglInitialize;
        errdefer _ = c.eglTerminate(display);

        std.log.info("EGL v{}.{}", .{major, minor});

        const config_attrs = [_]c.EGLint {
            c.EGL_BUFFER_SIZE, 32,
            c.EGL_RED_SIZE, 8,
            c.EGL_GREEN_SIZE, 8,
            c.EGL_BLUE_SIZE, 8,
            c.EGL_ALPHA_SIZE, 8,

            c.EGL_DEPTH_SIZE, 24,

            c.EGL_CONFORMANT, c.EGL_OPENGL_BIT,
            c.EGL_RENDERABLE_TYPE, c.EGL_OPENGL_BIT,
            c.EGL_SURFACE_TYPE, c.EGL_WINDOW_BIT,
            c.EGL_NONE
        };
        var config: c.EGLConfig = undefined;
        var n_configs: c_int = 0;
        result = c.eglChooseConfig(
            display,
            config_attrs[0..config_attrs.len],
            &config,
            1,
            &n_configs
        );
        if (result != c.EGL_TRUE) return error.BadConfig;
        if (n_configs == 0) return error.NoConfigs;

        const context_attrs = [_]c.EGLint {
            c.EGL_CONTEXT_MAJOR_VERSION, 3,
            c.EGL_CONTEXT_MINOR_VERSION, 2,
            c.EGL_CONTEXT_OPENGL_PROFILE_MASK
                , c.EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT,
            c.EGL_CONTEXT_OPENGL_FORWARD_COMPATIBLE, c.EGL_TRUE,
            c.EGL_NONE
        };
        const context = c.eglCreateContext(
            display,
            config,
            c.EGL_NO_CONTEXT,
            context_attrs[0..context_attrs.len]
        );
        if (context == c.EGL_NO_CONTEXT) return error.BadContext;
        errdefer _ = c.eglDestroyContext(display, context);

        const surface = c.eglCreatePlatformWindowSurface(
            display,
            config,
            @ptrCast(*c_void, &window.window),
            null
        );
        if (surface == c.EGL_NO_SURFACE) return error.BadSurface;
        errdefer _ = c.eglDestroySurface(display, surface);

        result = c.eglMakeCurrent(display, surface, surface, context);
        if (result != c.EGL_TRUE) return error.BadMakeCurrent;

        if (c.gladLoadEGL() == 0) return error.BadGlad;

        self.* = GlRenderer {
            .display = display,
            .surface = surface,
            .context = context
        };
    }

    pub fn deinit(self: *GlRenderer) void {
        _ = c.eglDestroySurface(self.display, self.surface);
        _ = c.eglDestroyContext(self.display, self.context);
        _ = c.eglTerminate(self.display);
    }
};

fn error_string(err: i32) []const u8 {
    switch (err) {
        c.EGL_SUCCESS => return "EGL_SUCCESS",
        c.EGL_NOT_INITIALIZED => return "EGL_NOT_INITIALIZED",
        c.EGL_BAD_ACCESS => return "EGL_BAD_ACCESS",
        c.EGL_BAD_ALLOC => return "EGL_BAD_ALLOC",
        c.EGL_BAD_ATTRIBUTE => return "EGL_BAD_ATTRIBUTE",
        c.EGL_BAD_CONTEXT => return "EGL_BAD_CONTEXT",
        c.EGL_BAD_CONFIG => return "EGL_BAD_CONFIG",
        c.EGL_BAD_CURRENT_SURFACE => return "EGL_BAD_CURRENT_SURFACE",
        c.EGL_BAD_DISPLAY => return "EGL_BAD_DISPLAY",
        c.EGL_BAD_SURFACE => return "EGL_BAD_SURFACE",
        c.EGL_BAD_MATCH => return "EGL_BAD_MATCH",
        c.EGL_BAD_PARAMETER => return "EGL_BAD_PARAMETER",
        c.EGL_BAD_NATIVE_PIXMAP => return "EGL_BAD_NATIVE_PIXMAP",
        c.EGL_BAD_NATIVE_WINDOW => return "EGL_BAD_NATIVE_WINDOW",
        c.EGL_CONTEXT_LOST => return "EGL_CONTEXT_LOST",
        else => return "UNKNOWN ERROR"
    }
}
