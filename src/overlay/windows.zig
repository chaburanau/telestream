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
    hwnd: ?win.HWND,
    crKey: u32,
    bAlpha: u8,
    dwFlags: c_int,
) callconv(win.WINAPI) win.BOOL;

pub const LAYERED_WINDOW_ATTRIBUTES_FLAGS = packed struct(u32) {
    COLORKEY: u1 = 0,
    ALPHA: u1 = 0,
    _2: u1 = 0,
    _3: u1 = 0,
    _4: u1 = 0,
    _5: u1 = 0,
    _6: u1 = 0,
    _7: u1 = 0,
    _8: u1 = 0,
    _9: u1 = 0,
    _10: u1 = 0,
    _11: u1 = 0,
    _12: u1 = 0,
    _13: u1 = 0,
    _14: u1 = 0,
    _15: u1 = 0,
    _16: u1 = 0,
    _17: u1 = 0,
    _18: u1 = 0,
    _19: u1 = 0,
    _20: u1 = 0,
    _21: u1 = 0,
    _22: u1 = 0,
    _23: u1 = 0,
    _24: u1 = 0,
    _25: u1 = 0,
    _26: u1 = 0,
    _27: u1 = 0,
    _28: u1 = 0,
    _29: u1 = 0,
    _30: u1 = 0,
    _31: u1 = 0,
};
