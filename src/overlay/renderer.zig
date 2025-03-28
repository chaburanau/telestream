const std = @import("std");
const model = @import("model.zig");
const drawer = @import("drawer.zig");
const colors = @import("colors.zig");
const errors = @import("errors.zig");
const windows_ui = @import("../windows/ui.zig");

const component_input = @import("component_input.zig");

const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("windows.h");
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
    @cInclude("SDL3/SDL_revision.h");
});

pub const Renderer = struct {
    const NAME = "Overlay";
    const VERSION = "v0.0.1";
    const IDENTIFIER = "com.telestream.overlay";
    const WINDOW_FLAGS =
        c.SDL_WINDOW_BORDERLESS |
        c.SDL_WINDOW_FULLSCREEN |
        c.SDL_WINDOW_TRANSPARENT |
        c.SDL_WINDOW_ALWAYS_ON_TOP |
        c.SDL_WINDOW_NOT_FOCUSABLE;

    const BACKGROUD = model.Color{
        .r = 0,
        .g = 0,
        .b = 0,
        .a = 0,
    };

    scale_x: f32 = 2.0,
    scale_y: f32 = 2.0,
    screen_x: u32 = 0,
    screen_y: u32 = 0,

    window: ?*c.SDL_Window = null,
    renderer: ?*c.SDL_Renderer = null,
    drawer: ?drawer.Drawer = null,

    pub fn init() Renderer {
        return Renderer{};
    }

    pub fn start(self: *Renderer) !void {
        errdefer |err| if (err == error.SdlError) std.log.err("SDL error: {s}", .{c.SDL_GetError()});

        c.SDL_SetMainReady();

        try errors.errify(c.SDL_SetAppMetadata(NAME, VERSION, IDENTIFIER));
        try errors.errify(c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO | c.SDL_INIT_GAMEPAD));
        try errors.errify(c.SDL_CreateWindowAndRenderer(NAME, 0, 0, WINDOW_FLAGS, &self.window, &self.renderer));

        try errors.errify(c.SDL_SetWindowKeyboardGrab(self.window, false));
        try errors.errify(c.SDL_SetWindowMouseGrab(self.window, false));

        self.drawer = drawer.Drawer.init(@ptrCast(self.renderer));

        // Click-through transparency
        const hwnd = c.SDL_GetPointerProperty(c.SDL_GetWindowProperties(self.window), c.SDL_PROP_WINDOW_WIN32_HWND_POINTER, c.NULL).?;
        const casted: std.os.windows.HWND = @ptrCast(hwnd);
        const getLong = windows_ui.GetWindowLongA(casted, c.GWL_EXSTYLE);
        const setLong = windows_ui.SetWindowLongA(casted, c.GWL_EXSTYLE, getLong | c.WS_EX_LAYERED | c.WS_EX_TRANSPARENT);
        const attribs = windows_ui.SetLayeredWindowAttributes(casted, c.RGB(255, 0, 255), 0, c.LWA_COLORKEY);
        _ = setLong;
        _ = attribs;

        self.screen_x = @intCast(c.GetSystemMetrics(c.SM_CXSCREEN));
        self.screen_y = @intCast(c.GetSystemMetrics(c.SM_CYSCREEN));

        std.log.debug("Resolution: {d}x{d}", .{ self.screen_x, self.screen_y });
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

            const input = component_input.ComponentInput{
                .scale = 1.0,
                .size = model.Size{
                    .h = 100,
                    .w = 40,
                },
                .position = model.Position{
                    .x = 500,
                    .y = 500,
                },
                .clutch = 0.4,
                .brake = 0.5,
                .throttle = 0.6,
            };

            try self.reset();
            try input.render(&self.drawer.?);
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

    fn reset(self: *Renderer) !void {
        try errors.errify(c.SDL_SetRenderDrawColor(self.renderer, BACKGROUD.r, BACKGROUD.g, BACKGROUD.b, BACKGROUD.a));
        try errors.errify(c.SDL_SetRenderScale(self.renderer, self.scale_x, self.scale_y));
        try errors.errify(c.SDL_RenderClear(self.renderer));
    }

    fn render(self: *Renderer) !void {
        try errors.errify(c.SDL_RenderPresent(self.renderer));
    }
};
