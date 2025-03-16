const std = @import("std");

const model = @import("iracing/model.zig");
const client = @import("iracing/client.zig");
const source = @import("iracing/source.zig");
const events = @import("iracing/event.zig");
const session = @import("iracing/session.zig");
const overlay = @import("overlay/entry.zig");

const IRacingAPIURL = "http://127.0.0.1:32034";
const IRacingTelemetryFileName = "Local\\IRSDKMemMapFileName";
const IRacingDataEventFileName = "Local\\IRSDKDataValidEvent";

pub fn main() !void {
    // var renderer = overlay.Renderer.init();
    // defer renderer.stop();
    // try renderer.start();
    //

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    // const is_running = try client.isRunning(allocator, IRacingAPIURL);
    if (true) {
        const src = try source.Source.fromMemory(IRacingTelemetryFileName);
        defer src.deinit() catch {};
        const loop = try events.EventLoop.fromWindowsEventFile(IRacingDataEventFileName);
        defer loop.deinit() catch {};

        var clt = try client.Client.init(allocator, src, loop);
        var updater = Updater{ .allocator = allocator };
        try clt.run(&updater);
    }
}

const Updater = struct {
    allocator: std.mem.Allocator,

    pub fn update(
        _: Updater,
        head: model.Header,
        sess: model.Session,
        vars: model.Variables,
        vals: model.Values,
    ) !bool {
        std.debug.print("Header: {any}\n", .{head});
        for (sess.info.keys()) |key| {
            std.debug.print("Session key: {s}\n", .{key});
        }

        for (0..vars.items.len) |index| {
            std.debug.print("Name: {s}; Type: {any}; Offset: {d}; Count: {d}; Value: {any}\n", .{
                vars.items[index].name,
                vars.items[index].type,
                vars.items[index].offset,
                vars.items[index].count,
                vals.items[index],
            });
        }

        return false;
    }
};

pub const std_options = std.Options{
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .parse, .level = .err },
        .{ .scope = .parser, .level = .err },
        .{ .scope = .tokenizer, .level = .err },
    },
};
