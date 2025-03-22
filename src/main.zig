const std = @import("std");

const model = @import("iracing/model.zig");
const iracing = @import("iracing/client.zig");
const overlay = @import("overlay/renderer.zig");

const IRacingAPIURL = "http://127.0.0.1:32034";
const IRacingTelemetryFileName = "Local\\IRSDKMemMapFileName";
const IRacingDataEventFileName = "Local\\IRSDKDataValidEvent";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const is_running = try iracing.isRunning(allocator, IRacingAPIURL);
    if (is_running) {
        var client = try iracing.Client.init(allocator, IRacingTelemetryFileName, IRacingDataEventFileName);
        defer client.deinit();
        try debugIRacing(allocator, &client);
    }

    var renderer = overlay.Renderer.init();
    defer renderer.stop();
    try renderer.start();
}

pub fn debugIRacing(allocator: std.mem.Allocator, client: *iracing.Client) !void {
    const PRINT_SESSION = false;
    const PRINT_VARIABLES = false;
    const ITERATION_COUNT = 3;

    var header = try client.getHeader();

    var session = try client.getSession(header);
    defer session.deinit(allocator);

    var variables = try client.getVariables(header);
    defer variables.deinit(allocator);

    var values = try client.getValues(header, variables);
    defer values.deinit(allocator);

    for (0..ITERATION_COUNT) |_| {
        try client.wait(1000);
        std.time.sleep(10 * 1000 * 1000 * 1000);

        header = try client.getHeader();
        const buffer = header.lastBuffer();
        if (session.version != header.session_version) {
            session.deinit(allocator);
            session = try client.getSession(header);
        }
        if (variables.items.len != variables.items.len) {
            variables.deinit(allocator);
            variables = try client.getVariables(header);
        }
        if (values.buffer.tick != buffer.tick) {
            values.deinit(allocator);
            values = try client.getValues(header, variables);
        }

        std.debug.print("Header:\n", .{});
        std.debug.print("\tState: {any}\n", .{header.state});
        std.debug.print("\tHeader Version: {d}\n", .{header.version});
        std.debug.print("\tSession Version: {d}\n", .{header.session_version});
        std.debug.print("\tBuffer Version: {d}\n", .{buffer.tick});

        std.debug.print("Session:\n", .{});
        std.debug.print("\tTrack Name: {s}\n", .{try session.info.get([]const u8, "WeekendInfo.TrackName")});
        std.debug.print("\tEvent Type: {s}\n", .{try session.info.get([]const u8, "WeekendInfo.TrackConfigName.EventType")});
        std.debug.print("\tSim Mode: {s}\n", .{try session.info.get([]const u8, "WeekendInfo.TrackConfigName.SimMode")});
        std.debug.print("\tLap: {d}\n", .{try session.info.get(i64, "SessionInfo.Sessions.0.SessionSubType.ResultsPositions.0.Lap")});
        std.debug.print("\tPosition: {d}\n", .{try session.info.get(i64, "SessionInfo.Sessions.0.SessionSubType.ResultsPositions.0.Position")});
        std.debug.print("\tFastest Time: {d}\n", .{try session.info.get(f64, "SessionInfo.Sessions.0.SessionSubType.ResultsPositions.0.FastestTime")});
        std.debug.print("\tLaps Completed: {d}\n", .{try session.info.get(i64, "SessionInfo.Sessions.0.SessionSubType.ResultsPositions.0.LapsComplete")});
        std.debug.print("\tDriver Name: {s}\n", .{try session.info.get([]const u8, "DriverInfo.Drivers.0.UserName")});
        std.debug.print("\tCar Name: {s}\n", .{try session.info.get([]const u8, "DriverInfo.Drivers.0.AbbrevName.Initials.CarScreenName")});
        std.debug.print("\tFuel Level: {s}\n", .{try session.info.get([]const u8, "CarSetup.Chassis.Rear.FuelLevel")});

        if (PRINT_SESSION) {
            std.debug.print("\n\n\n", .{});
            try session.info.stringify(std.io.getStdOut().writer());
            std.debug.print("\n\n\n", .{});
        }

        std.debug.print("Variables:\n", .{});

        std.debug.print("\tSession Time: {any}\n", .{values.items[variables.find("SessionTime").?]});
        std.debug.print("\tSession Tick: {any}\n", .{values.items[variables.find("SessionTick").?]});
        std.debug.print("\tSession State: {any}\n", .{values.items[variables.find("SessionState").?]});
        std.debug.print("\tIs On Track: {any}\n", .{values.items[variables.find("IsOnTrack").?]});
        std.debug.print("\tFrameRate: {any}\n", .{values.items[variables.find("FrameRate").?]});
        //        std.debug.print("\tTireCompound: {any}\n", .{values.items[variables.find("TireCompound").?]});
        std.debug.print("\tSteering Wheel Angle: {any}\n", .{values.items[variables.find("SteeringWheelAngle").?]});
        std.debug.print("\tThrottle: {any}\n", .{values.items[variables.find("Throttle").?]});
        std.debug.print("\tBrake: {any}\n", .{values.items[variables.find("Brake").?]});
        std.debug.print("\tClutch: {any}\n", .{values.items[variables.find("Clutch").?]});
        std.debug.print("\tGear: {any}\n", .{values.items[variables.find("Gear").?]});
        std.debug.print("\tRPM: {any}\n", .{values.items[variables.find("RPM").?]});
        std.debug.print("\tLap: {any}\n", .{values.items[variables.find("Lap").?]});
        std.debug.print("\tLapCompleted: {any}\n", .{values.items[variables.find("LapCompleted").?]});
        std.debug.print("\tSpeed: {any}\n", .{values.items[variables.find("Speed").?]});

        if (PRINT_VARIABLES) {
            for (0..variables.items.len) |index| {
                const variable = variables.items[index];
                const value = values.items[index];
                std.debug.print("\tName: {s}\n", .{variable.name});
                std.debug.print("\t\tDesc: {s}\n", .{variable.desc});
                std.debug.print("\t\tUnit: {s}\n", .{variable.unit});
                std.debug.print("\t\tCount: {d}\n", .{variable.count});
                std.debug.print("\t\tType: {any}\n", .{variable.type});
                std.debug.print("\t\tValue: {any}\n", .{value});
            }
        }
    }
}

pub const std_options = std.Options{
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .parse, .level = .err },
        .{ .scope = .parser, .level = .err },
        .{ .scope = .tokenizer, .level = .err },
    },
};
