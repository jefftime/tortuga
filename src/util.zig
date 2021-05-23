usingnamespace @import("c.zig");
usingnamespace @import("mem.zig");

pub fn read_file(filename: []const u8) ![]u8 {
    const file = c.fopen(filename.ptr, "rb") orelse return error.FileNotFound;
    defer _ = c.fclose(file);

    var rc = c.fseek(file, 0, c.SEEK_END);
    if (rc == -1) return error.BadFileSeek;

    const len = c.ftell(file);
    if (len == -1) return error.BadFtell;
    if (len == 0) return error.EmptyFile;

    rc = c.fseek(file, 0, c.SEEK_SET);
    if (rc == -1) return error.BadFileSeek;

    // Allocate len + 1 to append terminating character
    const buf = try alloc(u8, @intCast(usize, len) + 1);
    errdefer dealloc(buf.ptr);

    const bytes_read = c.fread(buf.ptr, 1, @intCast(c_ulong, len), file);
    if (bytes_read != len) return error.BadFileRead;
    buf[@intCast(usize, len)] = 0;

    return buf;
}
