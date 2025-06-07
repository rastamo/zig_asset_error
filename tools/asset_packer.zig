const std = @import("std");
const fs = std.fs;

const BlobRef = struct {
    offset: usize,
    len: usize,
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    const blob_path = try std.fs.path.join(allocator, &.{ "packed", "blob.binary" });
    var blob_file = try fs.cwd().createFile(blob_path, .{ .truncate = true });
    defer blob_file.close();
    const blob_writer = blob_file.writer();

    const blob_index = try std.fs.path.join(allocator, &.{ "src", "blob_init.zig" });
    var file = try fs.cwd().createFile(blob_index, .{});
    const writer = file.writer();

    var assets = std.StringHashMap(BlobRef).init(allocator);
    defer assets.deinit();

    var cwd = try fs.cwd().openDir("assets", .{ .iterate = true });
    defer cwd.close();

    var walker = try cwd.walk(allocator);
    defer walker.deinit();

    var offset: usize = 0;
    var sw = StructWriter.init(writer);
    try sw.write("const std = @import(\"{s}\");\n", .{"std"});
    try sw.write("const rl = @import(\"{s}\");\n", .{"raylib"});
    try sw.write("const blob = @embedFile(\"{s}\");\n", .{"blob"});
    try sw.write("const blob_index = @import(\"{s}\").blob_index;\n", .{"blob_index.zig"});
    try sw.write("const BlobRef = @import(\"{s}\").BlobRef;\n", .{"blob_index.zig"});
    try helperFns(writer);
    while (try walker.next()) |entry| {
        // try writer.print("{s}\n", .{entry.path});
        if (entry.kind == .directory) {
            const curr_depth = std.mem.count(u8, entry.path, std.fs.path.sep_str);
            const depth_diff = sw.depth - curr_depth;
            for (0..depth_diff) |_| {
                try sw.close();
            }
            try sw.open(entry.basename);
        } else if (entry.kind == .file) {
            try sw.file(entry);

            const data = try cwd.readFileAlloc(allocator, entry.path, 16 * 1024 * 1024);
            const path = try std.mem.replaceOwned(u8, allocator, entry.path, "\\", "_");
            try assets.put(path, .{ .offset = offset, .len = data.len });
            offset += data.len;

            try blob_writer.writeAll(data);
        }
    }
    for (0..sw.depth) |_| {
        try sw.close();
    }
    try createBlobIndex(allocator, &assets);
}

fn helperFns(w: std.fs.File.Writer) !void {
    const loadTextureFromMemory =
        \\fn loadTextureFromMemory(comptime path: []const u8) !rl.Texture {
        \\    const ref = blob_index.get(path) orelse BlobRef{.offset = 7603198, .len = 55682};
        \\    const data = blob[ref.offset .. ref.offset + ref.len];
        \\    const image = try rl.loadImageFromMemory(".png", data);
        \\    const texture = try rl.loadTextureFromImage(image);
        \\    rl.unloadImage(image);
        \\    return texture;
        \\}
    ;
    try w.print("{s}\n", .{loadTextureFromMemory});
    const loadMusicFromMemory =
        \\fn loadMusicFromMemory(comptime path: []const u8) !rl.Music {
        \\    const ref = blob_index.get(path) orelse BlobRef{.offset = 7603198, .len = 55682};
        \\    const data = blob[ref.offset .. ref.offset + ref.len];
        \\    const music_stream = try rl.loadMusicStreamFromMemory(".mp3", data);
        \\    return music_stream;
        \\}
    ;
    try w.print("{s}\n", .{loadMusicFromMemory});
    const loadFontFromMemory =
        \\fn loadFontFromMemory(comptime path: []const u8) !rl.Font {
        \\    const ref = blob_index.get(path) orelse BlobRef{.offset = 7603198, .len = 55682};
        \\    const data = blob[ref.offset .. ref.offset + ref.len];
        \\    const font = try rl.loadFontFromMemory(".ttf", data, 20, null);
        \\    return font;
        \\}
    ;
    try w.print("{s}\n", .{loadFontFromMemory});
}
const StructWriter = struct {
    writer: fs.File.Writer,
    depth: usize = 0,

    fn init(writer: fs.File.Writer) StructWriter {
        return .{ .writer = writer };
    }
    fn writeIndent(self: *StructWriter) !void {
        try self.writer.writeByteNTimes(' ', self.depth * 4);
    }
    fn write(self: *StructWriter, comptime format: []const u8, args: anytype) !void {
        try self.writeIndent();
        try self.writer.print(format, args);
    }
    fn open(self: *StructWriter, name: []const u8) !void {
        try self.writeIndent();
        try self.writer.print("pub const {s} = struct {{\n", .{name});
        self.depth +|= 1;
    }

    fn close(self: *StructWriter) !void {
        self.depth -|= 1;
        try self.writeIndent();
        try self.writer.writeAll("};\n");
    }
    fn file(self: *StructWriter, entry: fs.Dir.Walker.Entry) !void {
        if (std.mem.eql(u8, std.fs.path.extension(entry.basename), ".png")) {
            try self.texture(entry);
        } else if (std.mem.eql(u8, std.fs.path.extension(entry.basename), ".mp3")) {
            try self.audio(entry);
        } else if (std.mem.eql(u8, std.fs.path.extension(entry.basename), ".tff")) {
            try self.font(entry);
        }
    }
    fn audio(self: *StructWriter, entry: fs.Dir.Walker.Entry) !void {
        const name = std.fs.path.stem(entry.basename);
        const arg = try fmtKey(entry.path);
        try self.write("var var{s}: ?rl.Music = null;\n", .{name});
        try self.write("pub fn {s}() rl.Music{{\n", .{name});
        try self.write("    if (var{s} == null) {{\n", .{name});
        try self.write("        var{s} = loadMusicFromMemory(\"{s}\") catch unreachable;\n", .{ name, arg });
        try self.write("    }}\n", .{});
        try self.write("    return var{s}.?;\n", .{name});
        try self.write("}}\n", .{});
    }
    fn font(self: *StructWriter, entry: fs.Dir.Walker.Entry) !void {
        const name = std.fs.path.stem(entry.basename);
        const arg = try fmtKey(entry.path);
        try self.write("var var{s}: ?rl.Font= null;\n", .{name});
        try self.write("pub fn {s}() rl.Font{{\n", .{name});
        try self.write("    if (var{s} == null) {{\n", .{name});
        try self.write("        var{s} = loadFontFromMemory(\"{s}\") catch unreachable;\n", .{ name, arg });
        try self.write("    }}\n", .{});
        try self.write("    return var{s}.?;\n", .{name});
        try self.write("}}\n", .{});
    }
    fn texture(self: *StructWriter, entry: fs.Dir.Walker.Entry) !void {
        const name = std.fs.path.stem(entry.basename);
        const arg = try fmtKey(entry.path);
        try self.write("var var{s}: ?rl.Texture = null;\n", .{name});
        try self.write("pub fn {s}() rl.Texture {{\n", .{name});
        try self.write("    if (var{s} == null) {{\n", .{name});
        try self.write("        var{s} = loadTextureFromMemory(\"{s}\") catch unreachable;\n", .{ name, arg });
        try self.write("    }}\n", .{});
        try self.write("    return var{s}.?;\n", .{name});
        try self.write("}}\n", .{});
    }
};
fn fmtKey(path_arg: []const u8) ![]const u8 {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    const path = try std.mem.replaceOwned(u8, allocator, path_arg, "\\", "_");
    return path;
}
fn createBlobIndex(allocator: std.mem.Allocator, assets: *std.StringHashMap(BlobRef)) !void {
    const blob_index = try std.fs.path.join(allocator, &.{ "src", "blob_index.zig" });
    var file = try fs.cwd().createFile(blob_index, .{});
    const writer = file.writer();

    try writer.writeAll("const std = @import(\"std\");\n");
    try writer.writeAll("pub const BlobRef = struct{offset: usize, len: usize};\n\n");
    try writer.writeAll("pub const blob_index = std.StaticStringMap(BlobRef).initComptime(.{\n");

    var it = assets.iterator();
    while (it.next()) |entry| {
        const key = entry.key_ptr.*;
        const val = entry.value_ptr.*;
        try writer.print("    .{{ \"{s}\", BlobRef{{ .offset = {d}, .len = {d} }} }},\n", .{ key, val.offset, val.len });
    }
    try writer.writeAll("});\n");
}
