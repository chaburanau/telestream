const std = @import("std");
const heap = std.heap;
const http = std.http;
const win = std.os.windows;
const windows = @import("windows.zig");

const IRacingAPIURL = "http://127.0.0.1:32034";
const StatusEndpoint = "/get_sim_status?object=simStatus";
const IRacingTelemetryFileName = "Local\\IRSDKMemMapFileName";
const IRacingDataEventFileName = "Local\\IRSDKDataValidEvent";

const SimError = error{
    SimNotRunning,
};

const Header = extern struct {
    version: i32,
    status: i32,
    tick_rate: i32,
    session_info_version: i32,
    session_info_lenght: i32,
    session_info_offset: i32,
    n_vars: i32,
    header_offset: i32,
    n_buffers: i32,
    buffer_length: i32,
    padding: [2]u32,
    buffers: [4]ValueBuffer,
};

const ValueBuffer = extern struct {
    ticks: i32,
    offset: i32,
    padding: [2]u32,
};

const ValueHeader = extern struct {
    value_type: i32,
    offset: i32,
    count: i32,
    count_as_time: bool,

    _pad: [3]u8,
    _name: [32]c_char,
    _desc: [64]c_char,
    _unit: [32]c_char,
};

const Tick = extern struct {
    number: i32,
    buffer: []u8,
    values: []ValueHeader,
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

    const header_memory = @as([*]u8, @ptrCast(@alignCast(location)))[0..@sizeOf(Header)];
    const header: Header = std.mem.bytesAsValue(Header, header_memory).*;

    const beginning: usize = @intCast(header.session_info_offset);
    const ending: usize = @intCast(header.session_info_offset + header.session_info_lenght);

    const session_memory = @as([*]u8, @ptrCast(@alignCast(location)))[beginning..ending];
    const session: []u8 = std.mem.bytesAsSlice(u8, session_memory);

    std.debug.print("\nHeader: {any}", .{header});
    std.debug.print("\nSession: {s}", .{session});
}
