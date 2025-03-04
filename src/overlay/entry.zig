const std = @import("std");
const windows = @import("windows.zig");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("windows.h");
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
    @cInclude("SDL3/SDL_revision.h");
});

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const Position = struct {
    x: f32,
    y: f32,
};

const Size = struct {
    w: f32,
    h: f32,
};

pub const Renderer = struct {
    SCALE: f32 = 1.0,

    window: ?*c.SDL_Window = null,
    renderer: ?*c.SDL_Renderer = null,

    const NAME = "Overlay";
    const VERSION = "v0.0.1";
    const IDENTIFIER = "com.telestream.overlay";
    const WINDOW_FLAGS =
        c.SDL_WINDOW_BORDERLESS |
        c.SDL_WINDOW_FULLSCREEN |
        c.SDL_WINDOW_TRANSPARENT |
        c.SDL_WINDOW_ALWAYS_ON_TOP |
        c.SDL_WINDOW_NOT_FOCUSABLE;

    const BACKGROUD = Color{
        .r = 0,
        .g = 0,
        .b = 0,
        .a = 0,
    };

    pub fn init() Renderer {
        return Renderer{};
    }

    pub fn start(self: *Renderer) !void {
        errdefer |err| if (err == error.SdlError) std.log.err("SDL error: {s}", .{c.SDL_GetError()});

        c.SDL_SetMainReady();

        try errify(c.SDL_SetAppMetadata(NAME, VERSION, IDENTIFIER));
        try errify(c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO | c.SDL_INIT_GAMEPAD));
        try errify(c.SDL_CreateWindowAndRenderer(NAME, 0, 0, WINDOW_FLAGS, &self.window, &self.renderer));

        try errify(c.SDL_SetWindowKeyboardGrab(self.window, false));
        try errify(c.SDL_SetWindowMouseGrab(self.window, false));

        const hwnd = c.SDL_GetPointerProperty(c.SDL_GetWindowProperties(self.window), c.SDL_PROP_WINDOW_WIN32_HWND_POINTER, c.NULL).?;
        const casted: std.os.windows.HWND = @ptrCast(hwnd);
        const getLong = windows.GetWindowLongA(casted, c.GWL_EXSTYLE);
        const setLong = windows.SetWindowLongA(casted, c.GWL_EXSTYLE, getLong | c.WS_EX_LAYERED | c.WS_EX_TRANSPARENT);
        const attribs = windows.SetLayeredWindowAttributes(casted, c.RGB(255, 0, 255), 0, c.LWA_COLORKEY);
        _ = setLong;
        _ = attribs;

        std.log.debug("SDL version: {d}.{d}.{d}; Revision: {s}", .{
            c.SDL_MAJOR_VERSION,
            c.SDL_MINOR_VERSION,
            c.SDL_MICRO_VERSION,
            c.SDL_REVISION,
        });
        std.log.debug("SDL Video Drivers: {s}:{d}", .{ c.SDL_GetCurrentVideoDriver(), c.SDL_GetNumVideoDrivers() });
        std.log.debug("SDL Audio Drivers: {s}:{d}", .{ c.SDL_GetCurrentAudioDriver(), c.SDL_GetNumAudioDrivers() });
        std.log.debug("SDL Render Drivers: {s}:{d}", .{ c.SDL_GetRendererName(self.renderer), c.SDL_GetNumRenderDrivers() });

        try self.loop();
    }

    pub fn stop(self: *Renderer) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    fn loop(self: *Renderer) !void {
        while (true) {
            var event: c.SDL_Event = undefined;
            while (c.SDL_PollEvent(&event)) {
                const exit = self.handleEvent(event);
                if (exit) return;
            }

            try self.reset();

            try self.drawRectange(
                Position{ .x = 100, .y = 100 },
                Size{ .w = 100, .h = 100 },
                Color{ .r = 0, .g = 0, .b = 0, .a = 0xFF },
            );
            try self.drawText(
                "Testing",
                Position{ .x = 101, .y = 101 },
                Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF },
            );

            try self.render();
        }
    }

    fn handleEvent(_: *Renderer, event: c.SDL_Event) bool {
        switch (event.type) {
            c.SDL_EVENT_QUIT => {
                return true;
            },
            else => {
                return false;
            },
        }
    }

    fn drawRectange(self: *Renderer, position: Position, size: Size, color: Color) !void {
        const rects = [_]c.SDL_FRect{.{ .x = position.x, .y = position.y, .w = size.w, .h = size.h }};
        try errify(c.SDL_SetRenderDrawColor(self.renderer, color.r, color.g, color.b, color.a));
        try errify(c.SDL_RenderRect(self.renderer, rects[0..]));
    }

    fn drawText(self: *Renderer, text: []const u8, position: Position, color: Color) !void {
        try errify(c.SDL_SetRenderDrawColor(self.renderer, color.r, color.g, color.b, color.a));
        try errify(c.SDL_RenderDebugText(self.renderer, position.x, position.y, text.ptr));
    }

    fn reset(self: *Renderer) !void {
        try errify(c.SDL_SetRenderDrawColor(self.renderer, BACKGROUD.r, BACKGROUD.g, BACKGROUD.b, BACKGROUD.a));
        try errify(c.SDL_RenderClear(self.renderer));
    }

    fn render(self: *Renderer) !void {
        try errify(c.SDL_RenderPresent(self.renderer));
    }
};

// Converts the return value of an SDL function to an error union.
inline fn errify(value: anytype) error{SdlError}!switch (@import("shims.zig").typeInfo(@TypeOf(value))) {
    .bool => void,
    .pointer, .optional => @TypeOf(value.?),
    .int => |info| switch (info.signedness) {
        .signed => @TypeOf(@max(0, value)),
        .unsigned => @TypeOf(value),
    },
    else => @compileError("unerrifiable type: " ++ @typeName(@TypeOf(value))),
} {
    return switch (@import("shims.zig").typeInfo(@TypeOf(value))) {
        .bool => if (!value) error.SdlError,
        .pointer, .optional => value orelse error.SdlError,
        .int => |info| switch (info.signedness) {
            .signed => if (value >= 0) @max(0, value) else error.SdlError,
            .unsigned => if (value != 0) value else error.SdlError,
        },
        else => comptime unreachable,
    };
}
