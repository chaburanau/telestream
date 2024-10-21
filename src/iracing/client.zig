const std = @import("std");
const heap = std.heap;
const http = std.http;

pub fn check_running(url: []const u8) !bool {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(url);

    const header_allocator: []u8 = try allocator.alloc(u8, 1024);
    defer allocator.free(header_allocator);

    var request = try client.open(.GET, uri, .{ .server_header_buffer = header_allocator });
    defer request.deinit();

    try request.send();
    try request.finish();
    try request.wait();

    const body = try request.reader().readAllAlloc(allocator, 8192);
    defer allocator.free(body);

    return true;
}
