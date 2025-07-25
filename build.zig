const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a library that can be used as a dependency
    const lib = b.addStaticLibrary(.{
        .name = "wasmpl",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install the library
    b.installArtifact(lib);

    // Create a WebAssembly version of the library
    const wasm_lib = b.addStaticLibrary(.{
        .name = "wasmpl-wasm",
        .root_source_file = b.path("src/template.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = optimize,
    });

    // Install the WebAssembly library
    b.installArtifact(wasm_lib);

    // Create a step to build WebAssembly
    const wasm_step = b.step("wasm", "Build WebAssembly library");
    wasm_step.dependOn(&wasm_lib.step);

    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("tests/template_test.zig"),
        .target = target,
        .optimize = optimize,
        .filters = b.args orelse &.{},
    });

    // Add the src directory to the test's module path
    tests.root_module.addImport("wasmpl", lib.root_module);

    // Debug
    const lldb = b.addSystemCommand(&.{
        "lldb",
        "--",
    });
    lldb.addArtifactArg(tests);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const lldb_test = b.step("debug", "run the tests with lldb");
    lldb_test.dependOn(&lldb.step);
}
