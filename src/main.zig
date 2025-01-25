const std = @import("std");
const yaml = @import("yaml");

const iclient = @import("iracing/client.zig");
const controller = @import("iracing/controller.zig");
const source = @import("iracing/source.zig");
const event_loop = @import("iracing/event.zig");
const header = @import("iracing/header.zig");
const mapper = @import("iracing/mapper.zig");
const session = @import("iracing/session.zig");

const IRacingAPIURL = "http://127.0.0.1:32034";
const IRacingTelemetryFileName = "Local\\IRSDKMemMapFileName";
const IRacingDataEventFileName = "Local\\IRSDKDataValidEvent";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const src = try source.Source.fromMemory(IRacingTelemetryFileName);
    defer src.deinit() catch {};
    const loop = try event_loop.EventLoop.fromWindowsEventFile(IRacingDataEventFileName);
    defer loop.deinit() catch {};

    const size = @sizeOf(header.Header);
    const header_data = try allocator.alloc(u8, size);
    defer allocator.free(header_data);

    try src.read(0, header_data);
    const head = try mapper.mapStruct(header.Header, header_data);

    const session_info_data = try allocator.alloc(u8, @intCast(head.session_info_lenght));
    defer allocator.free(session_info_data);

    try src.read(@intCast(head.session_info_offset), session_info_data);

    std.debug.print("\n\n\n Header: {any}", .{head});
    std.debug.print("\n\n\n", .{});

    var session_info = try session.SessionInfo.init(allocator, session_info_data);
    defer session_info.deinit();
    for (session_info.keys()) |key| {
        std.debug.print("{s}\n", .{key});
    }

    const path = "WeekendInfo.WeekendOptions.WindSpeed";
    const result = try session_info.get([]const u8, path);
    std.debug.print("value for {s} is {s}", .{ path, result });
}

pub const std_options = std.Options{
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .parse, .level = .err },
        .{ .scope = .tokenizer, .level = .err },
    },
};
