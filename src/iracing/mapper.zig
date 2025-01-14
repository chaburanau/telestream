const std = @import("std");
const headers = @import("header.zig");

pub fn mapStruct(comptime T: type, data: []const u8) !T {
    switch (T) {
        headers.Header => {},
        headers.ValueHeader => {},
        else => {},
    }

    return std.mem.bytesAsValue(T, data).*;
}

pub fn mapArray(comptime T: type, allocator: std.mem.Allocator, data: []const u8, count: usize) !std.ArrayList(T) {
    var array = std.ArrayList(T).initCapacity(allocator, count);
    const size = @sizeOf(T);

    for (0..count) |index| {
        const chunk = data[index * size .. (index + 1) * size];
        const value = mapStruct(T, chunk);
        try array.append(value);
    }

    return array;
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
