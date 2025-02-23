const std = @import("std");
const windows = @import("windows.zig");

pub const EventLoop = struct {
    windows_event_loop: ?WindowsEventLoop = null,

    pub fn fromWindowsEventFile(event_file: []const u8) !EventLoop {
        const event_loop = try WindowsEventLoop.init(event_file);
        return EventLoop{ .windows_event_loop = event_loop };
    }

    pub fn deinit(self: EventLoop) !void {
        if (self.windows_event_loop) |event_loop| {
            try event_loop.deinit();
        }
    }

    pub fn wait(self: EventLoop, duration: u32) !void {
        if (self.windows_event_loop) |event_loop| {
            try event_loop.wait(duration);
        }
    }
};

const WindowsEventLoop = struct {
    events: std.os.windows.HANDLE,

    fn init(event_file: []const u8) !WindowsEventLoop {
        const handle_name: [:0]const u8 = @ptrCast(event_file);
        const handle = try windows.openEventA(0x00100000, 0, handle_name.ptr);
        return WindowsEventLoop{ .events = handle };
    }

    fn deinit(self: WindowsEventLoop) !void {
        std.os.windows.CloseHandle(self.events);
    }

    fn wait(self: WindowsEventLoop, duration: u32) !void {
        try std.os.windows.WaitForSingleObject(self.events, duration);
    }
};
