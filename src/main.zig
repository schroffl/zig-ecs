const std = @import("std");
const set = @import("set.zig");
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
            data: *EntityData,

            /// TODO Write doc comments
            pub fn add(self: *Entity, comptime Tag: TagT) *Data(Tag) {
                return self.data.add(Tag);
            }

            /// TODO Write doc comments
            pub fn get(self: *Entity, comptime Tag: TagT) ?*Data(Tag) {
                return self.data.get(Tag);
            }

            /// TODO Write doc comments
            pub fn has(self: Entity, comptime Tag: TagT) bool {
                return self.data.has(Tag);
            }

            // TODO When removing a component from an entity we currently
            // no longer have the ability to safely unwrap the .get optional
            // in a systems processFn.
            //
            //   This could be solved by having a separate removal set in
            // the EntityData with which we track the comoponents to be
            // remove. The actual unsetting then only happens when the
            // user calls Manager.signal on the entity, after which the
            // set can be cleared again.
            //
            //   One downside to this is that we have two FixedBit sets in
            // EntityData, which increases the size. This shouldn't be
            // too much of a issue though, because the main memory
            // consumption will come from the actual component data
            // anyways.

            /// TODO Write doc comments
            pub fn remove(self: *Entity, comptime Tag: TagT) void {
                return self.data.remove(Tag);
            }
        };

        /// TODO Write doc comments
        pub const System = struct {
            const Instance = struct {
                interface: *System,
                entities: set.Bits,
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
            pub const Flags = set.FixedBits(@memberCount(Components));
            pub const Size = util.DataSize(Components);

            flags: Flags,
            data: [Size]u8,

            pub fn init() EntityData {
                return EntityData{
                    .flags = Flags.init(),
                    .data = []u8{0} ** Size,
                };
            }

            /// Check whether an entity has a given component attached
            pub fn has(self: *EntityData, comptime Component: TagT) bool {
                return self.flags.has(getComponentFlag(Component));
            }

            /// Attach a given component to an entity.
            /// Returns a pointer to the component data of said entity.
            /// The entity must not have the component already enabled!
            pub fn add(self: *EntityData, comptime Component: TagT) *Data(Component) {
                std.debug.assert(!self.has(Component));
                self.flags.add(getComponentFlag(Component));
                return self.getDataPtr(Component);
            }

            /// Remove a given component from an entity
            pub fn remove(self: *EntityData, comptime Component: TagT) void {
                self.flags.delete(getComponentFlag(Component));
            }

            /// Get a pointer to the component data of an entity
            pub fn get(self: *EntityData, comptime Component: TagT) ?*Data(Component) {
                return if (self.has(Component)) self.getDataPtr(Component) else null;
            }

            fn getComponentFlag(comptime Component: TagT) usize {
                return @intCast(usize, @enumToInt(Component));
            }

            fn getDataPtr(self: *EntityData, comptime Component: TagT) *Data(Component) {
                const T = Data(Component);
                const offset = comptime util.DataOffset(Components, Component);

                return @intToPtr(*T, @ptrToInt(&self.data[0]) + offset);
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
            sys.entities = set.Bits.init(self.allocator);
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
                        .data = self.getEntityData(id),
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

            return Entity{ .id = idx, .data = ptr };
        }

        /// TODO Write doc comments
        pub fn signal(self: *Self, entity: Entity) !void {
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
        self.result += entity.get(.Integer).?.*;
    }
};

test "Creating entities and adding/removing components" {
    var manager = TestManager.init(std.debug.global_allocator);
    var entity = try manager.spawn();

    std.testing.expect(!entity.has(.Transform));

    var transform = entity.add(.Transform);
    transform.x = 42;

    const got = entity.get(.Transform);
    std.testing.expect(entity.has(.Transform));
    std.testing.expectEqual(got, transform);
    std.testing.expectEqual(got.?.x, 42);
}

test "Running systems" {
    var manager = TestManager.init(std.debug.global_allocator);
    var entity = try manager.spawn();
    var math_system = MathTestSystem.init();

    try manager.addSystem(&math_system.system);

    var int = entity.add(.Integer);
    int.* = 42;

    try manager.signal(entity);
    manager.runSystems();

    std.testing.expectEqual(math_system.result, 150);
}
