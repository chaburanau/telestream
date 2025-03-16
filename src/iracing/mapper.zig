const std = @import("std");
const headers = @import("header.zig");

const MapError = error{
    UnsupportedType,
};

pub fn mapStruct(comptime T: type, data: []u8) !T {
    switch (T) {
        headers.Header => {},
        headers.ValueHeader => {},
        else => {},
    }

    return std.mem.bytesAsValue(T, data).*;
}

pub fn mapSlice(comptime T: type, allocator: std.mem.Allocator, data: []u8) ![]T {
    const size: usize = @sizeOf(T);
    const count: usize = @intCast(data.len / size);
    const slice = try allocator.alloc(T, count);

    for (0..count) |index| {
        const chunk = data[index * size .. (index + 1) * size];
        const value = try mapStruct(T, chunk);
        slice[index] = value;
    }

    return slice;
}

pub fn mapArray(comptime T: type, array: *std.ArrayList(T), data: []const u8, count: usize) !void {
    const size = @sizeOf(T);

    for (0..count) |index| {
        const chunk = data[index * size .. (index + 1) * size];
        const value = try mapStruct(T, chunk);
        array.items[index] = value;
    }
}

test "map header" {
    const testing = std.testing;

    const data = [_]u8{ 0, 0, 0, 1 };
    const result = try mapStruct(headers.Header, &data);

    try testing.expectEqual(1, result.version);
    try testing.expectEqual(2, result.status);
    try testing.expectEqual(3, result.tick_rate);
    try testing.expectEqual(4, result.session_info_version);
    try testing.expectEqual(5, result.session_info_lenght);
    try testing.expectEqual(6, result.session_info_offset);
    try testing.expectEqual(7, result.n_vars);
    try testing.expectEqual(8, result.header_offset);
    try testing.expectEqual(9, result.n_buffers);
    try testing.expectEqual(0, result.buffer_length);
}
