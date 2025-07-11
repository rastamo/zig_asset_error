const std = @import("std");
const rl = @import("raylib");

pub fn main() !void {
    var i: i32 = 1000;
    var buf: [64]u8 = undefined;
    while (i < 20000) : (i += 2000) {
        const image = rl.genImageColor(i, i, .blue);
        const filename = try std.fmt.bufPrintZ(&buf, "assets/textures/blue/image{d}.png", .{i});
        _ = rl.exportImage(image, filename);
    }
}
