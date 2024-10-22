const std = @import("std");
const heap = std.heap;
const http = std.http;
const win = std.os.windows;

const IRacingAPIURL = "http://127.0.0.1:32034";
const StatusEndpoint = "/get_sim_status?object=simStatus";

const SimError = error{
    SimNotRunning,
};

pub fn isRunning(url: []const u8) !bool {
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

    return std.mem.indexOf(u8, body, "running:1") == null;
}

pub fn start() !void {
    if (!try isRunning(IRacingAPIURL ++ StatusEndpoint)) return SimError.SimNotRunning;

    const file_size: usize = 544512; // 1191936
    const telemetry_file_path = "Local\\IRSDKMemMapFileName";

    var mem_file = try std.fs.openFileAbsolute(telemetry_file_path, .{});
    defer mem_file.close();

    const file_mapping = try CreateFileMappingA(mem_file.handle, null, win.PAGE_READONLY, 0, file_size, null);
    if (file_mapping == null) {
        return error.CreateFileMappingFailed;
    }
    defer win.CloseHandle(file_mapping);

    const mapped_mem = MapViewOfFile(file_mapping, std.os.FILE_MAP_READ, 0, 0, file_size);
    if (mapped_mem == null) {
        return error.MapViewFailed;
    }
    defer std.os.windows.UnmapViewOfFile(mapped_mem);
}

pub extern "kernel32" fn CreateFileMappingA(
    hFile: win.HANDLE,
    lpFileMappingAttributes: win.SECURITY_ATTRIBUTES,
    flProtect: win.DWORD,
    dwMaximumSizeHigh: win.DWORD,
    dwMaximumSizeLow: win.DWORD,
    lpName: win.LPCSTR,
) callconv(win.WINAPI) win.HANDLE;

pub extern "kernel32" fn MapViewOfFile(
    hFileMappingObject: win.HANDLE,
    dwDesiredAccess: win.DWORD,
    dwFileOffsetHigh: win.DWORD,
    dwFileOffsetLow: win.DWORD,
    dwNumberOfBytesToMap: win.SIZE_T,
) callconv(win.WINAPI) win.LPVOID;

pub extern "kernel32" fn UnmapViewOfFile(
    lpBaseAddress: win.LPCVOID,
) callconv(win.WINAPI) win.BOOL;
