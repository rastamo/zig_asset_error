const rl = @import("raylib");
const rlm = rl.math;
const std = @import("std");
const textures = @import("blob_init.zig").textures;
pub fn main() anyerror!void {
    rl.initWindow(600, 600, "AssetError");
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    const png: rl.Texture = textures.red.image1000();
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.drawTexture(png, 0, 0, .white);
        rl.endDrawing();
    }
}
