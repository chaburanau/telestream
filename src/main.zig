const std = @import("std");
const iclient = @import("iracing/client.zig");

const IRacingAPIURL = "http://127.0.0.1:32034";
const IRacingTelemetryFileName = "Local\\IRSDKMemMapFileName";
const IRacingDataEventFileName = "Local\\IRSDKDataValidEvent";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();
    const client = try iclient.Client.init(allocator, IRacingTelemetryFileName, IRacingDataEventFileName);

    const header = try client.readHeader();
    const vars = try client.readValueHeaders(header, allocator);
    defer vars.deinit();

    std.debug.print("\n\n\n Header: {any}", .{header});
    std.debug.print("\n\n\n Value Headers count: {any}", .{vars.items.len});
    std.debug.print("\n\n\n", .{});

    var count: i32 = 0;

    for (vars.items) |variable| {
        count += variable.count;
        std.debug.print("Name: {s}; Desc: {s}; Unit: {s}; Count: {d}; Value Type: {d}\n", .{
            variable._name,
            variable._desc,
            variable._unit,
            variable.count,
            variable.value_type,
        });
    }

    std.debug.print("Count: {d}", .{count});

    const data = try allocator.alloc(u8, @intCast(header.buffer_length));
    defer allocator.free(data);

    client.read(@intCast(header.buffers[0].offset), data);
}
