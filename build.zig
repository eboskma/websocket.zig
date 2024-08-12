const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Define dependencies.
    const zlib = b.dependency("zlib", .{
        .target = target,
        .optimize = optimize,
    });
    const zlib_artifact = zlib.artifact("zlib");
    const zlib_module = zlib.module("zlib");

    // Define module
    const ws_module = b.addModule("ws", .{
        .root_source_file = b.path("src/main.zig"),
    });
    ws_module.addImport("zlib", zlib_module);
    ws_module.linkLibrary(zlib_artifact);

    // Build library.
    const ws_lib = b.addStaticLibrary(.{
        .name = "ws",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Link z library and zlib module.
    ws_lib.linkLibrary(zlib_artifact);
    ws_lib.root_module.addImport("zlib", zlib_module);
    b.installArtifact(ws_lib);

    // Build test.
    const test_compile = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .test_runner = b.path("test_runner.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_compile.linkLibrary(zlib_artifact);
    test_compile.root_module.addImport("zlib", zlib_module);

    const run_tests = b.addRunArtifact(test_compile);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Build examples.
    var bin = b.addExecutable(.{
        .name = "autobahn_client",
        .root_source_file = b.path("examples/autobahn_client.zig"),
        .target = target,
        .optimize = optimize,
    });
    // bin.linkLibrary(ws_lib);
    bin.root_module.addImport("ws", ws_module);
    b.installArtifact(bin);

    bin = b.addExecutable(.{
        .name = "wss",
        .root_source_file = b.path("examples/wss.zig"),
        .target = target,
        .optimize = optimize,
    });
    // bin.linkLibrary(ws_lib);
    bin.root_module.addImport("ws", ws_module);
    b.installArtifact(bin);
}

// to test single file
// $ zig test src/main.zig --deps zlib=zlib --mod zlib::zlib/src/main.zig -l z
