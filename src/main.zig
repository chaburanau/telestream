const std = @import("std");
const iclient = @import("iracing/client.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();
    const client = try iclient.Client.init();

    const header = client.readHeader();
    const vars = try client.readValueHeaders(header, allocator);
    defer vars.deinit();

    std.debug.print("\n\n\n Header: {any}", .{header});
    std.debug.print("\n\n\n Value Headers count: {any}", .{vars.items.len});
    std.debug.print("\n\n\n", .{});

    for (vars.items) |variable| {
        std.debug.print("Name: {s}; Desc: {s}; Unit: {s};\n", .{ variable._name, variable._desc, variable._unit });
    }
}
