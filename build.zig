const std = @import("std");
const B = std.Build;

pub fn build(b: *B) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add Raylib dependency
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    // Create assets
    // const tool_module = b.createModule(.{
    //     .root_source_file = b.path("tools/create_assets.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // tool_module.addImport("raylib", raylib_dep.module("raylib"));
    // tool_module.linkLibrary(raylib_dep.artifact("raylib"));
    // const create_assets_tool = b.addExecutable(.{
    //     .name = "create_assets",
    //     .root_module = tool_module,
    // });
    // create_assets_tool.linkLibrary(raylib_dep.artifact("raylib"));
    // const run_create_assets_tool = b.addRunArtifact(create_assets_tool);
    // b.getInstallStep().dependOn(&run_create_assets_tool.step);

    // Create blob and source files to access it.
    const asset_packer = b.addExecutable(.{
        .name = "asset_packer",
        .root_source_file = b.path("tools/asset_packer.zig"),
        .target = b.graph.host,
    });
    const run_asset_packer = b.addRunArtifact(asset_packer);
    std.debug.print("Install asset packer\n", .{});
    b.getInstallStep().dependOn(&run_asset_packer.step);

    // The primary executable
    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    root_module.addImport("raylib", raylib_dep.module("raylib"));
    root_module.linkLibrary(raylib_dep.artifact("raylib"));
    const exe = b.addExecutable(.{
        .name = "asset_error",
        .root_module = root_module,
    });

    b.installArtifact(exe);

    // Add the blob to the executable
    const blob_path = try std.fs.path.join(b.allocator, &.{ "packed", "blob.binary" });
    exe.root_module.addAnonymousImport("blob", .{
        .root_source_file = b.path(blob_path),
    });

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
