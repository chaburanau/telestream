const std = @import("std");
const heap = std.heap;
const http = std.http;
const win = std.os.windows;
const windows = @import("windows.zig");
const headers = @import("header.zig");

const IRacingAPIURL = "http://127.0.0.1:32034";
const StatusEndpoint = "/get_sim_status?object=simStatus";
const IRacingTelemetryFileName = "Local\\IRSDKMemMapFileName";
const IRacingDataEventFileName = "Local\\IRSDKDataValidEvent";

const SimError = error{
    SimNotRunning,
};

pub fn isRunning(url: ?[]const u8) !bool {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const endpoint = url orelse IRacingAPIURL ++ StatusEndpoint;
    const uri = try std.Uri.parse(endpoint);

    const header_allocator: []u8 = try allocator.alloc(u8, 1024);
    defer allocator.free(header_allocator);

    var request = try client.open(.GET, uri, .{ .server_header_buffer = header_allocator });
    defer request.deinit();

    try request.send();
    try request.finish();
    try request.wait();

    const body = try request.reader().readAllAlloc(allocator, 256);
    defer allocator.free(body);

    return std.mem.indexOf(u8, body, "running:1") != null;
}

pub fn start() !void {
    if (!try isRunning(null)) return SimError.SimNotRunning;

    const handle_name = try win.sliceToPrefixedFileW(null, IRacingTelemetryFileName);
    const handle = try windows.WinOpenFileMappingW(windows.FILE_MAP_READ, 0, handle_name.span().ptr);
    defer win.CloseHandle(handle);

    const location = try windows.WinMapViewOfFile(handle, windows.FILE_MAP_READ, 0, 0, 0);
    defer windows.WinUnmapViewOfFile(location) catch |err| std.debug.print("unmap view of file error: {any}", .{err});

    const events = try win.CreateEventEx(null, IRacingDataEventFileName, win.CREATE_EVENT_MANUAL_RESET, windows.FILE_MAP_READ);
    defer win.CloseHandle(events);

    const header_memory = @as([*]u8, @ptrCast(@alignCast(location)))[0..@sizeOf(headers.Header)];
    const header: headers.Header = std.mem.bytesAsValue(headers.Header, header_memory).*;

    // const beginning: usize = @intCast(header.session_info_offset);
    // const ending: usize = @intCast(header.session_info_offset + header.session_info_lenght);

    // const session_memory = @as([*]u8, @ptrCast(@alignCast(location)))[beginning..ending];
    // const session: []u8 = std.mem.bytesAsSlice(u8, session_memory);

    std.debug.print("\nHeader: {any}", .{header});
    // std.debug.print("\nSession: {s}", .{session});
}

pub const Client = struct {
    location: *anyopaque,
    handle: win.HANDLE,
    events: win.HANDLE,

    pub fn init() !Client {
        const handle_name = try win.sliceToPrefixedFileW(null, IRacingTelemetryFileName);
        const handle = try windows.WinOpenFileMappingW(windows.FILE_MAP_READ, 0, handle_name.span().ptr);
        const location = try windows.WinMapViewOfFile(handle, windows.FILE_MAP_READ, 0, 0, 0);
        const events = try win.CreateEventEx(null, IRacingDataEventFileName, win.CREATE_EVENT_MANUAL_RESET, windows.FILE_MAP_READ);

        const client = Client{
            .location = location,
            .handle = handle,
            .events = events,
        };

        return client;
    }

    pub fn deinit(self: Client) !void {
        windows.UnmapViewOfFile(self.location);
        win.CloseHandle(self.handle);
        win.CloseHandle(self.events);
    }

    pub fn read(self: Client, from: usize, until: usize) []u8 {
        const memory = @as([*]u8, @ptrCast(@alignCast(self.location)))[from..until];
        return memory;
    }

    pub fn readHeader(self: Client) headers.Header {
        const memory = self.read(0, @sizeOf(headers.Header));
        const header: headers.Header = std.mem.bytesAsValue(headers.Header, memory).*;

        return header;
    }

    pub fn readSessionDetails(self: Client, header: headers.Header) []u8 {
        const from: usize = @intCast(header.session_info_offset);
        const until: usize = @intCast(header.session_info_offset + header.session_info_lenght);

        const memory = self.read(from, until);
        const session: []u8 = std.mem.bytesAsSlice(u8, memory);

        return session;
    }

    pub fn readValueHeaders(self: Client, header: headers.Header, allocator: std.mem.Allocator) !headers.ValueHeaders {
        const n_vars: usize = @intCast(header.n_vars);
        const size: usize = @sizeOf(headers.ValueHeader);
        const from: usize = @intCast(header.header_offset);
        const until: usize = @intCast(from + size * n_vars);

        const memory = self.read(from, until);
        var values = try headers.ValueHeaders.initCapacity(allocator, size);

        for (0..n_vars) |index| {
            const chunk = memory[index * size .. (index + 1) * size];
            const value: headers.ValueHeader = std.mem.bytesAsValue(headers.ValueHeader, chunk).*;
            try values.append(value);
        }

        return values;
    }
};
