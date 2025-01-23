const std = @import("std");
const win = std.os.windows;
const windows = @import("windows.zig");

pub const EventLoop = struct {
    windows_event_loop: ?WindowsEventLoop = null,
};

const WindowsEventLoop = struct {
    events: win.HANDLE,

    fn init(event_file: []const u8) !WindowsEventLoop {
        const events = try win.CreateEventEx(null, event_file, win.CREATE_EVENT_MANUAL_RESET, windows.FILE_MAP_READ);
        return WindowsEventLoop{ .events = events };
    }

    fn deinit(self: WindowsEventLoop) !void {
        win.CloseHandle(self.events);
    }

    fn wait(self: WindowsEventLoop, duration: u32) !void {
        try win.WaitForSingleObject(self.events, duration);
    }
};
