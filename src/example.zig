const std = @import("std");
const ecs = @import("main.zig");

const Transform = struct {
    x: f32,
    y: f32,
};

const Universe = ecs.Manager(union(enum) {
    Transform: Transform,
    Name: []u8,
});

const Entity = Universe.Entity;
const System = Universe.System;

const PhysicsSystem = struct {
    system: System,

    pub fn init() PhysicsSystem {
        return PhysicsSystem{
            .system = System{
                .filterFn = filter,
                .processFn = process,
                .afterFn = null,
                .beforeFn = null,
            },
        };
    }

    pub fn filter(sys: *System, entity: Entity) bool {
        return entity.has(.Transform);
    }

    pub fn process(sys: *System, entity: *Entity) void {
        // We can unwrap the optional, because the filter function
        // assures that our entity has a transform
        var transform = entity.get(.Transform).?;

        transform.x += 1;
        transform.y += 2;
    }
};

const RenderSystem = struct {
    pub fn init() System {
        return System{
            .filterFn = filter,
            .processFn = process,
            .afterFn = null,
            .beforeFn = null,
        };
    }

    pub fn filter(sys: *System, entity: Entity) bool {
        return entity.has(.Transform) and entity.has(.Name);
    }

    pub fn process(sys: *System, entity: *Entity) void {
        const pos = entity.get(.Transform).?;
        const name = entity.get(.Name).?;

        std.debug.warn("{} is at ({.3}, {.3})\n", name.*, pos.x, pos.y);
    }
};

pub fn setName(allocator: *std.mem.Allocator, entity: *Entity, name: var) !void {
    var name_ref = entity.add(.Name);
    name_ref.* = try allocator.alloc(u8, name.len);
    std.mem.copy(u8, name_ref.*, name);
}

pub fn main() !void {
    var direct_allocator = std.heap.DirectAllocator.init();
    var allocator = &direct_allocator.allocator;
    var universe = Universe.init(allocator);

    var physics_system = PhysicsSystem.init();
    try universe.addSystem(&physics_system.system);

    var render_system = RenderSystem.init();
    try universe.addSystem(&render_system);

    var player = try universe.spawn();
    var transform = player.add(.Transform);

    try setName(allocator, &player, "John");
    transform.x = 42;
    transform.y = 10;

    try universe.signal(player);

    var system_runs: u32 = 10;

    while (system_runs > 0) : (system_runs -= 1) {
        universe.runSystems();
        // Wait 200ms between each run
        std.os.time.sleep(1000 * 1000 * 200);
    }
}
