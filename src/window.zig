const std = @import("std");
usingnamespace @import("c.zig");
usingnamespace @import("mem.zig");

pub const Window = struct {
    display: *c.Display,
    connection: *c.xcb_connection_t,
    window: c.xcb_window_t,
    delete_atom: c.xcb_atom_t,
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
        // var screen_index: c_int = undefined;
        // const cn = c.xcb_connect(null, &screen_index) orelse {
        //     std.log.err("could not establish XCB connection", .{});
        //     return error.BadConnection;
        // };

        const display = try setup_display();
        const connection = try setup_connection(display);
        const window = try setup_window(
            connection,
            title,
            width,
            height
        );
        const delete_atom = try get_delete_atom(connection, window);

        // Cursor
        const xfixes_cookie = c.xcb_xfixes_query_version(
            connection,
            4,
            0
        );
        var xfixes_err: ?*c.xcb_generic_error_t = null;
        const xfixes_reply = c.xcb_xfixes_query_version_reply(
            connection,
            xfixes_cookie,
            &xfixes_err
        );
        if (xfixes_err != null) {
            std.log.err("incompatible XFixes version: {}", .{xfixes_err});
            return error.BadXFixesVersion;
        }
        defer dealloc(xfixes_reply);

        _ = c.xcb_flush(connection);

        var e = c.xcb_wait_for_event(connection);
        while (e != null) : (e = c.xcb_wait_for_event(connection)) {
            if (e.*.response_type & 0x7f == c.XCB_EXPOSE) break;
            dealloc(e);
        }

        out_window.* = Window {
            .display = display,
            .connection = connection,
            .window = window,
            .delete_atom = delete_atom,
            .close = false,
            .title = title,
            .width = width,
            .height = height
        };
    }

    pub fn deinit(self: *const Window) void {
        self.show_cursor();
        std.log.info("closing XCB connection", .{});
        _ = c.xcb_xfixes_show_cursor(self.connection, self.window);
        _ = c.xcb_destroy_window(self.connection, self.window);
        _ = c.xcb_disconnect(self.connection);
    }

    pub fn update(self: *Window) void {
        var event = c.xcb_poll_for_event(self.*.connection);
        while (event != null)
            : (event = c.xcb_poll_for_event(self.*.connection)) {
                switch (event.*.response_type & 0x7f) {
                    // Resize
                    c.XCB_CONFIGURE_NOTIFY => {
                        var e = @ptrCast(
                            *c.xcb_configure_notify_event_t,
                            event
                        );
                        const flag =
                            (e.*.width != self.width)
                            or (e.*.height != self.height);
                        if (flag) {
                            self.width = e.*.width;
                            self.height = e.*.height;
                        }
                    },

                    // Close window
                    c.XCB_CLIENT_MESSAGE => {
                        var e = @ptrCast(
                            *c.xcb_client_message_event_t,
                            event
                        );
                        if (e.*.data.data32[0] == self.delete_atom) {
                            self.close = true;
                        }
                    },

                    else => {}
                }

                dealloc(event);
        }
    }

    pub fn show_cursor(self: *const Window) void {
        _ = c.xcb_xfixes_show_cursor(self.connection, self.window);
        _ = c.xcb_flush(self.connection);
    }

    pub fn hide_cursor(self: *const Window) void {
        _ = c.xcb_xfixes_hide_cursor(self.connection, self.window);
        _ = c.xcb_flush(self.connection);
    }

    pub fn should_close(self: *const Window) bool {
        return self.close;
    }
};


fn setup_display() !*c.Display {
    return c.XOpenDisplay(null) orelse return error.BadDisplay;
}

fn setup_connection(display: *c.Display) !*c.xcb_connection_t {
    return c.XGetXCBConnection(display) orelse {
        std.log.err(
            "could not create XCB connection from X11 Display",
            .{}
        );
        return error.BadConnection;
    };
}

fn setup_window(
    connection: *c.xcb_connection_t,
    title: []const u8,
    width: u16,
    height: u16
) !c.xcb_window_t {
    const setup = c.xcb_get_setup(connection);
    var screen_iter = c.xcb_setup_roots_iterator(setup);

    // var i: usize = 0;
    // while (i < screen_index) : (i += 1) {
    //     c.xcb_screen_next(&screen_iter);
    // }
    const screen = screen_iter.data;

    const window: c.xcb_window_t = c.xcb_generate_id(connection);
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
        connection,
        c.XCB_COPY_FROM_PARENT,
        window,
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
        connection,
        c.XCB_PROP_MODE_REPLACE,
        window,
        c.XCB_ATOM_WM_NAME,
        c.XCB_ATOM_STRING,
        8,
        @intCast(u32, title.len),
        @ptrCast([*c]const u8, title)
    );

    return window;
}

fn get_delete_atom(
    connection: *c.xcb_connection_t,
    window: c.xcb_window_t
) !c.xcb_atom_t {
    // Atoms
    const wm_protocols = "WM_PROTOCOLS";
    var protocol_ck = c.xcb_intern_atom(
        connection,
        0,
        @as(u16, wm_protocols.len),
        wm_protocols
    );
    var protocol = c.xcb_intern_atom_reply(
        connection,
        protocol_ck,
        null
    ) orelse {
        return error.InternAtom;
    };
    defer dealloc(protocol);

    const wm_delete_window = "WM_DELETE_WINDOW";
    var delete_ck = c.xcb_intern_atom(
        connection,
        0,
        @as(u16, wm_delete_window.len),
        wm_delete_window
    );
    var delete = c.xcb_intern_atom_reply(
        connection,
        delete_ck,
        null
    ) orelse {
        return error.InternAtom;
    };
    defer dealloc(delete);

    _ = c.xcb_change_property(
        connection,
        c.XCB_PROP_MODE_REPLACE,
        window,
        protocol.*.atom,
        c.XCB_ATOM_ATOM,
        32,
        1,
        &delete.*.atom
    );

    _ = c.xcb_map_window(connection, window);
    _ = c.xcb_flush(connection);

    std.log.info("XCB connection established!", .{});

    const coords = [_]u32 { 100, 100 };
    _ = c.xcb_configure_window(
        connection,
        window,
        c.XCB_CONFIG_WINDOW_X | c.XCB_CONFIG_WINDOW_Y,
        &coords
    );

    return delete.*.atom;
}
