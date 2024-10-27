const std = @import("std");
const heap = std.heap;
const http = std.http;
const win = std.os.windows;

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

    const body = try request.reader().readAllAlloc(allocator, 8192);
    defer allocator.free(body);

    return std.mem.indexOf(u8, body, "running:1") != null;
}

pub fn start() !void {
    if (!try isRunning(null)) return SimError.SimNotRunning;

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    // const allocator = gpa.allocator();
    const handle_name = try win.sliceToPrefixedFileW(null, IRacingTelemetryFileName);

    const handle = try WinOpenFileMappingW(FILE_MAP_READ, 0, handle_name.span().ptr);
    defer win.CloseHandle(handle);

    const location = try WinMapViewOfFile(handle, FILE_MAP_READ, 0, 0, 0);
    defer WinUnmapViewOfFile(location) catch |err| std.debug.print("unmap view of file error: {any}", .{err});

    const memory = @as([*]u8, @ptrCast(@alignCast(location)))[0..@sizeOf(Header)];
    const data = std.mem.bytesAsSlice(Header, memory);
    std.debug.print("\nMemory: {any}", .{memory});
    std.debug.print("\nData: {any}", .{data});
}

pub fn WinCreateFileMapping(
    hFile: win.HANDLE,
    lpFileMappingAttributes: ?*win.SECURITY_ATTRIBUTES,
    flProtect: win.DWORD,
    dwMaximumSizeHigh: win.DWORD,
    dwMaximumSizeLow: win.DWORD,
    lpName: ?win.LPCSTR,
) !win.HANDLE {
    const handle = CreateFileMappingA(hFile, lpFileMappingAttributes, flProtect, dwMaximumSizeHigh, dwMaximumSizeLow, lpName);
    if (handle) |h| {
        return h;
    } else {
        switch (win.kernel32.GetLastError()) {
            else => |err| return win.unexpectedError(err),
        }
    }
}

pub fn WinMapViewOfFile(
    hFileMappingObject: win.HANDLE,
    dwDesiredAccess: win.DWORD,
    dwFileOffsetHigh: win.DWORD,
    dwFileOffsetLow: win.DWORD,
    dwNumberOfBytesToMap: win.SIZE_T,
) !win.LPVOID {
    const address = MapViewOfFile(hFileMappingObject, dwDesiredAccess, dwFileOffsetHigh, dwFileOffsetLow, dwNumberOfBytesToMap);
    if (address) |addr| {
        return addr;
    } else {
        switch (win.kernel32.GetLastError()) {
            else => |err| return win.unexpectedError(err),
        }
    }
}

pub fn WinUnmapViewOfFile(
    lpBaseAddress: win.LPCVOID,
) !void {
    if (UnmapViewOfFile(lpBaseAddress) == 0) {
        switch (win.kernel32.GetLastError()) {
            else => |err| return win.unexpectedError(err),
        }
    }
}

pub fn WinOpenFileMappingW(
    dwDesiredAccess: win.DWORD,
    bInheritHandle: win.BOOL,
    lpName: win.LPCWSTR,
) !win.HANDLE {
    const handle = OpenFileMappingW(dwDesiredAccess, bInheritHandle, lpName);
    if (handle) |h| {
        return h;
    } else {
        switch (win.kernel32.GetLastError()) {
            else => |err| return win.unexpectedError(err),
        }
    }
}

pub const FILE_MAP_READ = 0x0002;
pub const FILE_MAP_WRITE = 0x0004;

pub extern "kernel32" fn CreateFileMappingA(
    hFile: win.HANDLE,
    lpFileMappingAttributes: ?*win.SECURITY_ATTRIBUTES,
    flProtect: win.DWORD,
    dwMaximumSizeHigh: win.DWORD,
    dwMaximumSizeLow: win.DWORD,
    lpName: ?win.LPCSTR,
) callconv(win.WINAPI) ?win.HANDLE;

pub extern "kernel32" fn MapViewOfFile(
    hFileMappingObject: win.HANDLE,
    dwDesiredAccess: win.DWORD,
    dwFileOffsetHigh: win.DWORD,
    dwFileOffsetLow: win.DWORD,
    dwNumberOfBytesToMap: win.SIZE_T,
) callconv(win.WINAPI) ?win.LPVOID;

pub extern "kernel32" fn UnmapViewOfFile(
    lpBaseAddress: win.LPCVOID,
) callconv(win.WINAPI) win.BOOL;

pub extern "kernel32" fn OpenFileMappingW(
    dwDesiredAccess: win.DWORD,
    bInheritHandle: win.BOOL,
    lpName: win.LPCWSTR,
) callconv(win.WINAPI) ?win.HANDLE;
