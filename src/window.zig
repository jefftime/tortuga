const std = @import("std");
usingnamespace @import("c.zig");
usingnamespace @import("mem.zig");

pub const Window = struct {
    cn: *c.xcb_connection_t,
    wn: c.xcb_window_t,
    win_delete: c.xcb_atom_t,
    close: bool,
    title: []const u8,
    width: u16,
    height: u16,

    pub fn init(
        out_window: *Window,
        title: []const u8,
        width: u16,
        height: u16
    ) !void {
        // Initial setup
        var screen_index: c_int = undefined;
        const cn = c.xcb_connect(null, &screen_index) orelse {
            std.log.err("could not establish XCB connection", .{});
            return error.BadConnection;
        };

        const setup = c.xcb_get_setup(cn);
        var screen_iter = c.xcb_setup_roots_iterator(setup);

        var i: usize = 0;
        while (i < screen_index) : (i += 1) {
            c.xcb_screen_next(&screen_iter);
        }
        const screen = screen_iter.data;

        // Window
        const wn: c.xcb_window_t = c.xcb_generate_id(cn);
        const mask: u32 = c.XCB_CW_BACK_PIXEL | c.XCB_CW_EVENT_MASK;
        const values = [_]u32 {
            screen.*.black_pixel,
            c.XCB_EVENT_MASK_KEY_RELEASE
                | c.XCB_EVENT_MASK_EXPOSURE
                | c.XCB_EVENT_MASK_KEY_PRESS
                | c.XCB_EVENT_MASK_STRUCTURE_NOTIFY
                | c.XCB_EVENT_MASK_POINTER_MOTION
                | c.XCB_EVENT_MASK_BUTTON_PRESS
                | c.XCB_EVENT_MASK_BUTTON_RELEASE
        };

        _ = c.xcb_create_window(
            cn,
            c.XCB_COPY_FROM_PARENT,
            wn,
            screen.*.root,
            0, 0,
            width, height,
            0,
            c.XCB_WINDOW_CLASS_INPUT_OUTPUT,
            screen.*.root_visual,
            mask,
            &values
        );
        _ = c.xcb_change_property(
            cn,
            c.XCB_PROP_MODE_REPLACE,
            wn,
            c.XCB_ATOM_WM_NAME,
            c.XCB_ATOM_STRING,
            8,
            @intCast(u32, title.len),
            @ptrCast([*c]const u8, title)
        );

        // Atoms
        const wm_protocols = "WM_PROTOCOLS";
        var protocol_ck = c.xcb_intern_atom(
            cn,
            0,
            @as(u16, wm_protocols.len),
            wm_protocols
        );
        var protocol = c.xcb_intern_atom_reply(cn, protocol_ck, null) orelse {
            return error.InternAtom;
        };
        defer dealloc(protocol);

        const wm_delete_window = "WM_DELETE_WINDOW";
        var delete_ck = c.xcb_intern_atom(
            cn,
            0,
            @as(u16, wm_delete_window.len),
            wm_delete_window
        );
        var delete = c.xcb_intern_atom_reply(cn, delete_ck, null) orelse {
            return error.InternAtom;
        };
        defer dealloc(delete);

        _ = c.xcb_change_property(
            cn,
            c.XCB_PROP_MODE_REPLACE,
            wn,
            protocol.*.atom,
            c.XCB_ATOM_ATOM,
            32,
            1,
            &delete.*.atom
        );
        const win_delete = delete.*.atom;

        _ = c.xcb_map_window(cn, wn);
        _ = c.xcb_flush(cn);

        std.log.info("XCB connection established!", .{});

        const coords = [_]u32 { 100, 100 };
        _ = c.xcb_configure_window(
            cn,
            wn,
            c.XCB_CONFIG_WINDOW_X | c.XCB_CONFIG_WINDOW_Y,
            &coords
        );

        // Cursor
        const xfixes_cookie = c.xcb_xfixes_query_version(cn, 4, 0);
        var xfixes_err: ?*c.xcb_generic_error_t = null;
        const xfixes_reply = c.xcb_xfixes_query_version_reply(
            cn,
            xfixes_cookie,
            &xfixes_err
        );
        if (xfixes_err != null) {
            std.log.err("incompatible XFixes version: {}", .{xfixes_err});
            return error.BadXFixesVersion;
        }
        defer dealloc(xfixes_reply);

        _ = c.xcb_flush(cn);

        var e = c.xcb_wait_for_event(cn);
        while (e != null) : (e = c.xcb_wait_for_event(cn)) {
            if (e.*.response_type & 0x7f == c.XCB_EXPOSE) break;
            dealloc(e);
        }


        out_window.* = Window {
            .cn = cn,
            .wn = wn,
            .win_delete = win_delete,
            .close = false,
            .title = title,
            .width = width,
            .height = height
        };
    }

    pub fn deinit(self: *const Window) void {
        self.show_cursor();
        std.log.info("closing XCB connection", .{});
        _ = c.xcb_xfixes_show_cursor(self.cn, self.wn);
        _ = c.xcb_destroy_window(self.cn, self.wn);
        c.xcb_disconnect(self.cn);
    }

    pub fn update(self: *Window) void {
        var event = c.xcb_poll_for_event(self.*.cn);
        while (event != null) : (event = c.xcb_poll_for_event(self.*.cn)) {
            switch (event.*.response_type & 0x7f) {
                // Resize
                c.XCB_CONFIGURE_NOTIFY => {
                    var e = @ptrCast(*c.xcb_configure_notify_event_t, event);
                    if ((e.*.width != self.width) or (e.*.height != self.height)) {
                        self.width = e.*.width;
                        self.height = e.*.height;
                    }
                },

                // Close window
                c.XCB_CLIENT_MESSAGE => {
                    var e = @ptrCast(*c.xcb_client_message_event_t, event);
                    if (e.*.data.data32[0] == self.win_delete) {
                        self.close = true;
                    }
                },

                else => {}
            }

            dealloc(event);
        }
    }

    pub fn show_cursor(self: *const Window) void {
        _ = c.xcb_xfixes_show_cursor(self.cn, self.wn);
        _ = c.xcb_flush(self.cn);
    }

    pub fn hide_cursor(self: *const Window) void {
        _ = c.xcb_xfixes_hide_cursor(self.cn, self.wn);
        _ = c.xcb_flush(self.cn);
    }

    pub fn should_close(self: *const Window) bool {
        return self.close;
    }
};
