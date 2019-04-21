const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zig-ecs", "src/main.zig");
    lib.setBuildMode(mode);

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    var benchmarks = b.addTest("src/benchmark.zig");
    benchmarks.setBuildMode(mode);
    benchmarks.addPackagePath("bench", "lib/zig-bench/bench.zig");

    const benchmark_step = b.step("benchmark", "Run benchmarks");
    benchmark_step.dependOn(&benchmarks.step);

    const example_exe = b.addExecutable("zig-ecs-example", "src/example.zig");
    example_exe.setBuildMode(mode);

    const run_example_cmd = example_exe.run();
    const example_step = b.step("run-example", "Run the example in src/example.zig");
    example_step.dependOn(&run_example_cmd.step);

    b.default_step.dependOn(&lib.step);
    b.installArtifact(lib);
}
