const std = @import("std");
const session = @import("session.zig");

pub const Header = extern struct {
    version: i32,
    status: i32,
    tick_rate: i32,
    session_version: i32,
    session_lenght: i32,
    session_offset: i32,
    number_of_variables: i32,
    variables_offset: i32,
    number_of_buffers: i32,
    buffers_length: i32,
    padding: [2]u32,
    buffers: [4]Buffer,
};

pub const Buffer = extern struct {
    tick: i32,
    offset: i32,
    padding: [2]u32,

    pub fn more(_: void, left: Buffer, right: Buffer) bool {
        return left.tick > right.tick;
    }
};

pub const VariableType = enum(i32) {
    char = 0,
    bool = 1,
    int = 2,
    bitfield = 3,
    float = 4,
    double = 5,
    count = 6,

    pub fn size(self: VariableType) usize {
        return switch (self) {
            .char, .bool => 1,
            .int, .bitfield, .float => 4,
            .double, .count => 8,
        };
    }

    pub fn Type(self: VariableType) type {
        return switch (self) {
            .char => u8,
            .bool => bool,
            .int => i32,
            .bitfield => i32,
            .float => f32,
            .double => f64,
            .count => i64,
        };
    }
};

pub const Variable = extern struct {
    type: VariableType,
    offset: i32,
    count: i32,
    count_as_time: bool,

    padding: [3]u8,
    name: [32]u8,
    desc: [64]u8,
    unit: [32]u8,

    pub fn size(self: Variable) usize {
        const count: usize = @intCast(self.count);
        return self.type.size() * count;
    }

    pub fn isArray(self: Variable) bool {
        return self.count > 1;
    }
};

pub const Value = union(enum) {
    char: u8,
    chars: []u8,
    bool: bool,
    bools: []bool,
    int: i32,
    ints: []i32,
    bitfield: i32,
    bitfields: []i32,
    float: f32,
    floats: []f32,
    double: f64,
    doubles: []f64,
    count: i64,
    counts: []i64,

    pub fn init(allocator: std.mem.Allocator, variable: Variable, data: []u8) !Value {
        const count: usize = @intCast(variable.count);
        const is_array = variable.isArray();

        return switch (variable.type) {
            .char => {
                if (is_array) return Value{ .chars = try Value.multi(u8, allocator, data, count) };
                return Value{ .char = try Value.single(u8, data) };
            },
            .bool => {
                if (is_array) return Value{ .bools = try Value.multi(bool, allocator, data, count) };
                return Value{ .bool = try Value.single(bool, data) };
            },
            .int => {
                if (is_array) return Value{ .ints = try Value.multi(i32, allocator, data, count) };
                return Value{ .int = try Value.single(i32, data) };
            },
            .bitfield => {
                if (is_array) return Value{ .bitfields = try Value.multi(i32, allocator, data, count) };
                return Value{ .bitfield = try Value.single(i32, data) };
            },
            .float => {
                if (is_array) return Value{ .floats = try Value.multi(f32, allocator, data, count) };
                return Value{ .float = try Value.single(f32, data) };
            },
            .double => {
                if (is_array) return Value{ .doubles = try Value.multi(f64, allocator, data, count) };
                return Value{ .double = try Value.single(f64, data) };
            },
            .count => {
                if (is_array) return Value{ .counts = try Value.multi(i64, allocator, data, count) };
                return Value{ .count = try Value.single(i64, data) };
            },
        };
    }

    pub fn deinit(self: Value, allocator: std.mem.Allocator) void {
        allocator.free(self);
    }

    // fn single(variable: Variable, data: []u8) Value {
    //     return switch (variable.type.Type()) {
    //         u8 => Value{ .char = data[0] },
    //         bool => Value{ .bool = data[0] > 0 },
    //         f32 => Value{ .float = std.mem.bytesToValue(f32, data) },
    //         f64 => Value{ .double = std.mem.bytesToValue(f64, data) },
    //         i64 => Value{ .count = std.mem.bytesToValue(i64, data) },
    //         i32 => {
    //             if (variable.type == .int) return Value{ .int = std.mem.bytesToValue(i32, data) };
    //             if (variable.type == .bitfield) return Value{ .bitfield = std.mem.bytesToValue(i32, data) };
    //             unreachable;
    //         },
    //         else => unreachable,
    //     };
    // }
    //
    // fn multi(allocator: std.mem.Allocator, variable: Variable, data: []u8) Value {
    //     switch (variable.type.Type()) {
    //         u8 => {
    //             const result = allocator.alloc(u8, variable.count);
    //             @memcpy(result, data);
    //             return Value{ .chars = result };
    //         },
    //     }
    // }
    //
    // fn parse(comptime T: type, allocator: std.mem.Allocator, variable: Variable, data: []u8) Value {
    //     if (!variable.isArray()) {
    //         return switch (variable.type.Type()) {
    //             u8 => Value{ .char = data[0] },
    //             bool => Value{ .bool = data[0] > 0 },
    //             f32 => Value{ .float = std.mem.bytesToValue(f32, data) },
    //             f64 => Value{ .double = std.mem.bytesToValue(f64, data) },
    //             i64 => Value{ .count = std.mem.bytesToValue(i64, data) },
    //             i32 => {
    //                 if (variable.type == .int) return Value{ .int = std.mem.bytesToValue(i32, data) };
    //                 if (variable.type == .bitfield) return Value{ .bitfield = std.mem.bytesToValue(i32, data) };
    //                 unreachable;
    //             },
    //             else => unreachable,
    //         };
    //     }
    // }

    fn single(comptime T: type, data: []const u8) !T {
        return switch (T) {
            u8 => data[0],
            bool => data[0] > 0,
            i32 => std.mem.bytesToValue(i32, data),
            f32 => std.mem.bytesToValue(f32, data),
            i64 => std.mem.bytesToValue(i64, data),
            f64 => std.mem.bytesToValue(f64, data),
            else => unreachable,
        };
    }

    fn multi(comptime T: type, allocator: std.mem.Allocator, data: []u8, count: usize) ![]T {
        const size = @sizeOf(T);
        var array = try allocator.alloc(T, count);

        for (0..count) |index| {
            const chunk = data[index * size .. (index + 1) * size];
            array[index] = try Value.single(T, chunk);
        }

        return array;
    }
};

pub const Session = struct {
    version: i32,
    info: session.SessionInfo,

    pub fn deinit(self: *Session, allocator: std.mem.Allocator) void {
        self.info.deinit(allocator);
    }
};

pub const Variables = struct {
    items: []Variable,

    pub fn deinit(self: *Variables, allocator: std.mem.Allocator) void {
        allocator.free(self.items);
    }
};

pub const Values = struct {
    buffer: Buffer,
    items: []Value,

    pub fn deinit(self: *Values, allocator: std.mem.Allocator) void {
        for (0..self.items.len) |index| {
            switch (self.items[index]) {
                .chars => |cap| allocator.free(cap),
                .bools => |cap| allocator.free(cap),
                .ints => |cap| allocator.free(cap),
                .bitfields => |cap| allocator.free(cap),
                .floats => |cap| allocator.free(cap),
                .doubles => |cap| allocator.free(cap),
                .counts => |cap| allocator.free(cap),
                else => {},
            }
        }

        allocator.free(self.items);
    }
};
