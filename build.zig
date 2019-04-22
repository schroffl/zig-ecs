const Builder = @import("std").build.Builder;
const builtin = @import("builtin");
const Mode = builtin.Mode;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const example_exe = b.addExecutable("zig-ecs-example", "src/example.zig");
    example_exe.setBuildMode(mode);

    const run_example_cmd = example_exe.run();
    const example_step = b.step("run-example", "Run the example in src/example.zig");
    example_step.dependOn(&run_example_cmd.step);

    const benchmark_step = b.step("benchmark", "Run benchmarks");

    inline for ([]Mode{ Mode.Debug, Mode.ReleaseFast, Mode.ReleaseSafe, Mode.ReleaseSmall }) |test_mode| {
        const mode_str = comptime modeToString(test_mode);

        const t = b.addTest("src/benchmark.zig");
        t.setBuildMode(test_mode);
        t.addPackagePath("bench", "lib/zig-bench/bench.zig");
        t.setNamePrefix(mode_str ++ " ");

        const t_step = b.step("benchmark-" ++ mode_str, "Run benchmarks in " ++ mode_str);
        t_step.dependOn(&t.step);
        benchmark_step.dependOn(t_step);
    }

    b.default_step.dependOn(&main_tests.step);
}

fn modeToString(mode: Mode) []const u8 {
    return switch (mode) {
        Mode.Debug => "debug",
        Mode.ReleaseFast => "release-fast",
        Mode.ReleaseSafe => "release-safe",
        Mode.ReleaseSmall => "release-small",
    };
}
