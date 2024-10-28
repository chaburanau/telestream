const std = @import("std");
const win = std.os.windows;

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
