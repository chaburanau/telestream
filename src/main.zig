const std = @import("std");
const warnings = @import("iracing/warnings.zig");
const client = @import("iracing/client.zig");

pub fn main() !void {
    const warn: warnings.EngineWarning = .engine_stalled;
    std.debug.print("Warning is: {}", .{warn});

    const address: []const u8 = "google.com";

    const result = try client.isRunning(address);
    std.debug.print("Result is: {}", .{result});

    try client.start();
}
