const std = @import("std");
const heap = std.heap;
const http = std.http;
const win = std.os.windows;
const windows = @import("windows.zig");
const headers = @import("header.zig");

const SimError = error{
    SimNotRunning,
};

pub fn isRunning(allocator: std.mem.Allocator, url: []const u8) !bool {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const endpoint = url ++ "/get_sim_status?object=simStatus";
    const uri = try std.Uri.parse(endpoint);
    const headers_data: [64]u8 = undefined;
    const body_data: [256]u8 = undefined;

    var request = try client.open(.GET, uri, .{ .server_header_buffer = headers_data });
    defer request.deinit();

    try request.send();
    try request.finish();
    try request.wait();

    const body = try request.read(body_data);

    return std.mem.indexOf(u8, body, "running:1") != null;
}

pub const Client = struct {
    allocator: std.mem.Allocator,
    location: *anyopaque,
    handle: win.HANDLE,
    events: win.HANDLE,

    pub fn init(allocator: std.mem.Allocator, telemetry_file: []const u8, event_file: []const u8) !Client {
        const handle_name = try win.sliceToPrefixedFileW(null, telemetry_file);
        const handle = try windows.openFileMappingW(windows.FILE_MAP_READ, 0, handle_name.span().ptr);
        const location = try windows.mapViewOfFile(handle, windows.FILE_MAP_READ, 0, 0, 0);
        const events = try win.CreateEventEx(null, event_file, win.CREATE_EVENT_MANUAL_RESET, windows.FILE_MAP_READ);

        const client = Client{
            .allocator = allocator,
            .location = location,
            .handle = handle,
            .events = events,
        };

        return client;
    }

    pub fn deinit(self: Client) !void {
        windows.unmapViewOfFile(self.location);
        win.CloseHandle(self.handle);
        win.CloseHandle(self.events);
    }

    pub fn read(self: Client, from: usize, buffer: []u8) void {
        const memory = @as([*]u8, @ptrCast(@alignCast(self.location)))[from .. from + buffer.len];
        @memcpy(buffer, memory);
    }

    pub fn readHeader(self: Client) !headers.Header {
        const size = @sizeOf(headers.Header);
        const data = try self.allocator.alloc(u8, size);
        defer self.allocator.free(data);
        self.read(0, data);

        return std.mem.bytesAsValue(headers.Header, data).*;
    }

    pub fn readSessionDetails(self: Client, header: headers.Header) ![]u8 {
        const from: usize = @intCast(header.session_info_offset);
        const data = try self.allocator.alloc(u8, header.session_info_lenght);
        self.read(from, data);

        return data;
    }

    pub fn readValueHeaders(self: Client, header: headers.Header, allocator: std.mem.Allocator) !headers.ValueHeaders {
        const n_vars: usize = @intCast(header.n_vars);
        const size: usize = @sizeOf(headers.ValueHeader);
        const from: usize = @intCast(header.header_offset);

        const data = try self.allocator.alloc(u8, size * n_vars);
        defer self.allocator.free(data);
        self.read(from, data);

        var values = try headers.ValueHeaders.initCapacity(allocator, n_vars);

        for (0..n_vars) |index| {
            const chunk = data[index * size .. (index + 1) * size];
            const value: headers.ValueHeader = std.mem.bytesAsValue(headers.ValueHeader, chunk).*;
            try values.append(value);
        }

        return values;
    }
};
