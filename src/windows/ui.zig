const std = @import("std");
const win = std.os.windows;

pub extern "user32" fn GetWindowLongA(
    hWnd: ?win.HWND,
    nIndex: i32,
) callconv(win.WINAPI) i32;

pub extern "user32" fn SetWindowLongA(
    hWnd: ?win.HWND,
    nIndex: i32,
    dwNewLong: i32,
) callconv(win.WINAPI) i32;

pub extern "user32" fn SetLayeredWindowAttributes(
    hWnd: ?win.HWND,
    crKey: u32,
    bAlpha: u8,
    dwFlags: c_int,
) callconv(win.WINAPI) win.BOOL;
