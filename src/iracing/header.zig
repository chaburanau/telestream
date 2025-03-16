const std = @import("std");

pub const Header = extern struct {
    version: i32,
    status: i32,
    tick_rate: i32,
    session_info_version: i32,
    session_info_lenght: i32,
    session_info_offset: i32,
    number_of_values: i32,
    value_header_offset: i32,
    number_of_buffers: i32,
    buffer_length: i32,
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

pub const ValueHeader = extern struct {
    value_type: ValueType,
    offset: i32,
    count: i32,
    count_as_time: bool,

    padding: [3]u8,
    name: [32]u8,
    desc: [64]u8,
    unit: [32]u8,

    pub fn size(self: ValueHeader) usize {
        const count: usize = @intCast(self.count);
        return self.value_type.size() * count;
    }
};

pub const ValueType = enum(i32) {
    char = 0,
    bool = 1,
    int = 2,
    bitfield = 3,
    float = 4,
    double = 5,
    count = 6,

    pub fn size(self: ValueType) usize {
        return switch (self) {
            .char, .bool => 1,
            .int, .bitfield, .float => 4,
            .double, .count => 8,
        };
    }
};

pub const Value = struct {
    data: []u8,
    type: ValueType,
    count: usize,

    pub fn parse(self: Value, comptime T: type) !T {
        return switch (T) {
            u8 => self.data[0],
            bool => self.data[0] > 0,
            i32 => std.mem.bytesToValue(i32, self.data),
            f32 => std.mem.bytesToValue(f32, self.data),
            i64 => std.mem.bytesToValue(i64, self.data),
            f64 => std.mem.bytesToValue(f64, self.data),
            []u8 => self.data,
            []bool => std.mem.bytesAsSlice(bool, self.data[0..]),
            []i32 => std.mem.bytesAsSlice(i32, @as([]align(4) u8, @alignCast(self.data[0..]))),
            []f32 => []f32{},
            []i64 => []i64{},
            []f64 => []f64{},
            else => unreachable,
        };
    }
};

// pub const Value = union(enum) {
//     char: u8,
//     chars: []u8,
//     bool: bool,
//     bools: []bool,
//     int: i32,
//     ints: []i32,
//     bitfield: i32,
//     bitfields: []i32,
//     float: f32,
//     floats: []f32,
//     double: f64,
//     doubles: []f64,
//     count: i64,
//     counts: []i64,
//
//     pub fn init(allocator: std.mem.Allocator, header: ValueHeader, data: []u8) !Value {
//         const array = header.count > 1;
//         const size = header.value_type.size();
//         const count: usize = @intCast(header.count);
//
//         return switch (header.value_type) {
//             .char => {
//                 return if (array) Value{ .chars = data } else Value{ .char = try Value.parse(u8, data) };
//             },
//             .bool => {
//                 return if (array) Value{ .bools = try Value.parseArray(bool, allocator, data, count, size) } else Value{ .bool = try Value.parse(bool, data) };
//             },
//             .int => {
//                 return if (array) Value{ .ints = try Value.parseArray(i32, allocator, data, count, size) } else Value{ .int = try Value.parse(i32, data) };
//             },
//             .bitfield => {
//                 return if (array) Value{ .bitfields = try Value.parseArray(i32, allocator, data, count, size) } else Value{ .bitfield = try Value.parse(i32, data) };
//             },
//             .float => {
//                 return if (array) Value{ .floats = try Value.parseArray(f32, allocator, data, count, size) } else Value{ .float = try Value.parse(f32, data) };
//             },
//             .double => {
//                 return if (array) Value{ .doubles = try Value.parseArray(f64, allocator, data, count, size) } else Value{ .double = try Value.parse(f64, data) };
//             },
//             .count => {
//                 return if (array) Value{ .counts = try Value.parseArray(i64, allocator, data, count, size) } else Value{ .count = try Value.parse(i64, data) };
//             },
//         };
//     }
//
//     pub fn parse(comptime T: type, data: []const u8) !T {
//         return switch (T) {
//             u8 => data[0],
//             bool => data[0] > 0,
//             i32 => std.mem.bytesToValue(i32, data),
//             f32 => std.mem.bytesToValue(f32, data),
//             i64 => std.mem.bytesToValue(i64, data),
//             f64 => std.mem.bytesToValue(f64, data),
//             else => unreachable,
//         };
//     }
//
//     pub fn parseArray(comptime T: type, _: std.mem.Allocator, data: []u8, count: usize, _: usize) ![]T {
//         return std.mem.bytesAsValue([*]T, data).*[0..count];
//         // const items = std.mem.bytesAsValue([*]T, data);
//         // var array: []T = undefined;
//         // array.len = count;
//         // array.ptr = @ptrCast(items);
//         // return array;
//         // var array = try allocator.alloc(T, count);
//         //
//         // for (0..count) |index| {
//         //     const chunk = data[index * size .. (index + 1) * size];
//         //     array[index] = try Value.parse(T, chunk);
//         // }
//         //
//         // return array;
//     }
// };
//
// Header: iracing.header.Header{ .version = 2, .status = 1, .tick_rate = 60, .session_info_version = 70, .session_info_lenght = 524288, .session_info_offset = 112, .n_vars = 324, .header_offset = 524400, .n_buffers = 3, .buffer_length = 7789, .padding = { 0, 0 }, .buffers = { iracing.header.ValueBuffer{ .ticks = 232896, .offset = 1114224, .padding = { ... } }, iracing.header.ValueBuffer{ .ticks = 232897, .offset = 1138800, .padding = { ... } }, iracing.header.ValueBuffer{ .ticks = 232895, .offset = 1163376, .padding = { ... } }, iracing.header.ValueBuffer{ .ticks = 0, .offset = 0, .padding = { ... } } } }
