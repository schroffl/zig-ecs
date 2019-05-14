const std = @import("std");
const Set = @import("set.zig");
const util = @import("util.zig");
const Allocator = std.mem.Allocator;

/// TODO Write doc comments
pub fn Manager(comptime U: type) type {
    return struct {
        const Self = @This();

        pub const Components = U;

        pub const TagT = @TagType(Components);

        pub const EntityId = usize;

        /// TODO Write doc comments
        pub const Entity = struct {
            id: EntityId,
            entity_data: *EntityData,

            /// Check whether an entity has a given component attached
            pub fn has(self: Entity, comptime Component: TagT) bool {
                return self.entity_data.flags.has(getComponentFlag(Component));
            }

            /// Attach a given component to an entity.
            pub fn add(self: *Entity, comptime Component: TagT) void {
                self.entity_data.add_flags.add(getComponentFlag(Component));
            }

            pub fn set(self: *Entity, comptime Component: TagT, data: Data(Component)) void {
                self.add(Component);
                var ptr = self.getDataPtr(Component);
                ptr.* = data;
            }

            /// Remove a given component from an entity
            pub fn remove(self: *Entity, comptime Component: TagT) void {
                self.entity_data.remove_flags.add(getComponentFlag(Component));
            }

            /// Get a pointer to the component data of an entity
            pub fn get(self: Entity, comptime Component: TagT) ?Data(Component) {
                return if (self.has(Component)) self.getDataPtr(Component).* else null;
            }

            /// TODO Write doc comments
            pub fn getPtr(self: *Entity, comptime Component: TagT) ?*Data(Component) {
                return if (self.has(Component)) self.getDataPtr(Component) else null;
            }

            fn getComponentFlag(comptime Component: TagT) usize {
                return @intCast(usize, @enumToInt(Component));
            }

            fn getDataPtr(self: Entity, comptime Component: TagT) *Data(Component) {
                const T = Data(Component);
                const offset = comptime util.DataOffset(Components, Component);

                return @intToPtr(*T, @ptrToInt(&self.entity_data.data[0]) + offset);
            }

            fn updateFlags(self: Entity) void {
                var data = self.entity_data;

                EntityData.Flags.unionize(&data.flags, data.add_flags);
                EntityData.Flags.subtract(&data.flags, data.remove_flags);
                data.add_flags.empty();
                data.remove_flags.empty();
            }
        };

        /// TODO Write doc comments
        pub const System = struct {
            const Instance = struct {
                interface: *System,
                entities: Set.Bits,
            };

            /// A function to determine whether a given entity will
            /// be handled by this system
            filterFn: fn (
                system: *System,
                entity: Entity,
            ) bool,

            /// TODO Write doc comments
            processFn: fn (
                system: *System,
                entity: *Entity,
            ) void,

            /// TODO Write doc comments
            beforeFn: ?fn (
                system: *System,
            ) void,

            /// TODO Write doc comments
            afterFn: ?fn (
                system: *System,
            ) void,
        };

        /// TODO Write doc comments
        pub const EntityData = struct {
            pub const Flags = Set.FixedBits(@memberCount(Components));
            pub const Size = util.DataSize(Components);

            flags: Flags,
            remove_flags: Flags,
            add_flags: Flags,
            data: [Size]u8,

            pub fn init() EntityData {
                return EntityData{
                    .flags = Flags.init(),
                    .remove_flags = Flags.init(),
                    .add_flags = Flags.init(),
                    .data = []u8{0} ** Size,
                };
            }
        };

        allocator: *std.mem.Allocator,
        entity_data: std.ArrayList(EntityData),
        systems: std.ArrayList(System.Instance),

        /// TODO Write doc comments
        pub fn init(allocator: *Allocator) Self {
            return Self{
                .allocator = allocator,
                .entity_data = std.ArrayList(EntityData).init(allocator),
                .systems = std.ArrayList(System.Instance).init(allocator),
            };
        }

        /// TODO Write doc comments
        pub fn deinit(self: Self) void {
            self.entity_data.deinit();

            for (self.systems.toSliceConst()) |system| system.entities.deinit();
            self.systems.deinit();
        }

        /// TODO Write doc comments
        pub fn addSystem(self: *Self, system: *System) !void {
            var sys = try self.systems.addOne();

            sys.interface = system;
            sys.entities = Set.Bits.init(self.allocator);
        }

        /// TODO Write doc comments
        pub fn runSystems(self: *Self) void {
            var systems = self.systems.toSlice();

            for (systems) |*system| {
                var interface = system.interface;
                var iterator = system.entities.iterate();

                if (interface.beforeFn) |before| before(interface);

                while (iterator.next()) |id| {
                    var entity = Entity{
                        .id = id,
                        .entity_data = self.getEntityData(id),
                    };

                    interface.processFn(interface, &entity);
                }

                if (interface.afterFn) |after| after(interface);
            }
        }

        /// TODO Write doc comments
        pub fn spawn(self: *Self) !Entity {
            const idx = self.entity_data.count();
            try util.ensureCapacity(&self.entity_data, idx);
            var ptr = self.entity_data.addOneAssumeCapacity();

            ptr.* = EntityData.init();

            return Entity{ .id = idx, .entity_data = ptr };
        }

        /// TODO Write doc comments
        pub fn signal(self: *Self, entity: Entity) !void {
            entity.updateFlags();

            for (self.systems.toSlice()) |*system| {
                var interface = system.interface;

                if (interface.filterFn(interface, entity))
                    try system.entities.add(entity.id);
            }
        }

        fn getEntityData(self: Self, entity_id: EntityId) *EntityData {
            return &self.entity_data.toSlice()[entity_id];
        }

        /// When you destroy an entity you may not access its data anymore.
        pub fn destroy(self: *Self, entity: *Entity) void {
            for (self.systems.toSlice()) |*system|
                system.entities.delete(entity.id);
        }

        /// TODO Write doc comments
        pub fn Data(comptime Tag: TagT) type {
            return util.Data(Components, Tag);
        }
    };
}

const TestManager = Manager(union(enum) {
    Transform: struct {
        x: f32,
        y: f32,
    },
    Integer: u32,
});

const MathTestSystem = struct {
    system: TestManager.System,
    result: u32,

    pub fn init() MathTestSystem {
        return MathTestSystem{
            .system = TestManager.System{
                .filterFn = filter,
                .processFn = process,
                .beforeFn = before,
                .afterFn = after,
            },
            .result = 0,
        };
    }

    fn before(sys: *TestManager.System) void {
        var self = @fieldParentPtr(MathTestSystem, "system", sys);
        self.result = 8;
    }

    fn after(sys: *TestManager.System) void {
        var self = @fieldParentPtr(MathTestSystem, "system", sys);
        self.result *= 3;
    }

    fn filter(sys: *TestManager.System, entity: TestManager.Entity) bool {
        return entity.has(.Integer);
    }

    fn process(sys: *TestManager.System, entity: *TestManager.Entity) void {
        var self = @fieldParentPtr(MathTestSystem, "system", sys);
        self.result += entity.get(.Integer).?;
    }
};

test "Creating entities and adding/removing components" {
    var manager = TestManager.init(std.debug.global_allocator);
    var entity = try manager.spawn();

    std.testing.expect(!entity.has(.Transform));
    entity.add(.Transform);
    try manager.signal(entity);

    var transform = entity.getPtr(.Transform);
    var got = entity.getPtr(.Transform);

    std.testing.expect(entity.has(.Transform));
    std.testing.expectEqual(transform, got);
}

test "Entity signalling" {
    var manager = TestManager.init(std.debug.global_allocator);
    var entity = try manager.spawn();

    entity.add(.Transform);
    std.testing.expect(!entity.has(.Transform));

    try manager.signal(entity);
    entity.remove(.Transform);
    std.testing.expect(entity.has(.Transform));

    try manager.signal(entity);
    std.testing.expect(!entity.has(.Transform));
}

test "Running systems" {
    var manager = TestManager.init(std.debug.global_allocator);

    var math_system = MathTestSystem.init();
    try manager.addSystem(&math_system.system);

    var entity = try manager.spawn();
    entity.set(.Integer, 42);
    try manager.signal(entity);

    manager.runSystems();

    std.testing.expectEqual(u32(150), math_system.result);
}
