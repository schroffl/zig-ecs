const std = @import("std");
const ecs = @import("main.zig");
const bench = @import("bench");

const Manager = ecs.Manager(union(enum) {
    Unsigned32: u32,
});

const TestSystem = struct {
    system: Manager.System,
    data: u32,

    pub fn init() TestSystem {
        return TestSystem{
            .system = Manager.System{
                .processFn = process,
                .filterFn = filter,
                .afterFn = null,
                .beforeFn = null,
            },
            .data = 0,
        };
    }

    fn process(sys: *Manager.System, entity: *Manager.Entity) void {
        var self = @fieldParentPtr(TestSystem, "system", sys);
        self.data += entity.get(.Unsigned32).?.*;
    }

    fn filter(sys: *Manager.System, entity: Manager.Entity) bool {
        return entity.has(.Unsigned32);
    }
};

test "Benchmarks" {
    try bench.benchmark(struct {
        const Arg = struct {
            systems: u32,
            entities: u32,
            system_runs: u32,

            fn runWith(arg: Arg, allocator: *std.mem.Allocator) !void {
                var manager = Manager.init(allocator);
                defer manager.deinit();

                var system_i: u32 = 0;

                while (system_i < arg.systems) : (system_i += 1) {
                    var system = TestSystem.init();
                    try manager.addSystem(&system.system);
                }

                var entity_i: u32 = 0;

                while (entity_i < arg.entities) : (entity_i += 1) {
                    var entity = try manager.spawn();
                    _ = entity.add(.Unsigned32);
                    try manager.signal(entity);
                }

                var run_i: u32 = 0;

                while (run_i < arg.system_runs) : (run_i += 1) {
                    manager.runSystems();
                }
            }
        };

        pub const args = []Arg{
            Arg{ .systems = 1, .entities = 50, .system_runs = 1 },
            Arg{ .systems = 1, .entities = 5000, .system_runs = 2 },
            Arg{ .systems = 1, .entities = 5000, .system_runs = 200 },
            Arg{ .systems = 0, .entities = 50000, .system_runs = 200 },
        };

        pub const iterations = 100;

        pub fn DirectAllocator(a: Arg) void {
            var direct_allocator = std.heap.DirectAllocator.init();
            defer direct_allocator.deinit();

            a.runWith(&direct_allocator.allocator) catch unreachable;
        }

        pub fn FixedBufferAllocator(a: Arg) void {
            var direct_allocator = std.heap.DirectAllocator.init();
            var allocator = &direct_allocator.allocator;
            defer direct_allocator.deinit();

            var buffer = allocator.alloc(u8, a.entities * 50 + a.systems * a.entities * 5) catch unreachable;
            var fixed_allocator = std.heap.FixedBufferAllocator.init(buffer);
            defer allocator.free(buffer);

            a.runWith(&fixed_allocator.allocator) catch unreachable;
        }

        pub fn ArenaAllocator(a: Arg) void {
            var direct_allocator = std.heap.DirectAllocator.init();
            var arena_allocator = std.heap.ArenaAllocator.init(&direct_allocator.allocator);
            defer direct_allocator.deinit();
            defer arena_allocator.deinit();

            a.runWith(&arena_allocator.allocator) catch unreachable;
        }
    });
}
