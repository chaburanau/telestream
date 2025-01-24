const std = @import("std");
const iclient = @import("iracing/client.zig");
const controller = @import("iracing/controller.zig");
const source = @import("iracing/source.zig");
const event_loop = @import("iracing/event.zig");
const header = @import("iracing/header.zig");
const mapper = @import("iracing/mapper.zig");

const IRacingAPIURL = "http://127.0.0.1:32034";
const IRacingTelemetryFileName = "Local\\IRSDKMemMapFileName";
const IRacingDataEventFileName = "Local\\IRSDKDataValidEvent";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const src = try source.Source.fromMemory(IRacingTelemetryFileName);

    const size = @sizeOf(header.Header);
    const data = try allocator.alloc(u8, size);
    defer allocator.free(data);

    try src.read(0, data);
    const head = try mapper.mapStruct(header.Header, data);

    std.debug.print("\n\n\n Header: {any}", .{head});
    std.debug.print("\n\n\n", .{});

    const loop = try event_loop.EventLoop.fromWindowsEventFile(IRacingDataEventFileName);

    for (0..1000) |index| {
        std.debug.print("\n{d} : {d}", .{index, std.time.timestamp()});
        try loop.wait(10000000);
    }
}
