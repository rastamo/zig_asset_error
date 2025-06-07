const std = @import("std");
const rl = @import("raylib");

pub fn main() !void {
    var i: i32 = 1000;
    var buf: [32]u8 = undefined;
    while (i < 20000) : (i += 2000) {
        const image = rl.genImageColor(i, i, .red);
        const filename = try std.fmt.bufPrintZ(&buf, "assets/image{d}.png", .{i});
        _ = rl.exportImage(image, filename);
    }
}
