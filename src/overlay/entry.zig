const std = @import("std");

const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
    @cInclude("SDL3/SDL_revision.h");
});

pub fn run() !void {
    errdefer |err| if (err == error.SdlError) std.log.err("SDL error: {s}", .{c.SDL_GetError()});

    std.log.debug("SDL version: {d}.{d}.{d}; Revision: {s}", .{
        c.SDL_MAJOR_VERSION,
        c.SDL_MINOR_VERSION,
        c.SDL_MICRO_VERSION,
        c.SDL_REVISION,
    });

    c.SDL_SetMainReady();

    try errify(c.SDL_SetAppMetadata("Overlay", "v0.0.1", "com.telestream.overlay"));
    try errify(c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO | c.SDL_INIT_GAMEPAD));
    defer c.SDL_Quit();

    const WINDOW_H = 640;
    const WINDOW_W = 480;
    const WINDOW_FLAGS = c.SDL_WINDOW_TRANSPARENT | c.SDL_WINDOW_BORDERLESS | c.SDL_WINDOW_ALWAYS_ON_TOP;

    errify(c.SDL_SetHint(c.SDL_HINT_RENDER_VSYNC, "1")) catch {};

    var window: ?*c.SDL_Window = undefined;
    var renderer: ?*c.SDL_Renderer = undefined;
    try errify(c.SDL_CreateWindowAndRenderer("Overlay", WINDOW_W, WINDOW_H, WINDOW_FLAGS, &window, &renderer));
    defer c.SDL_DestroyRenderer(renderer);
    defer c.SDL_DestroyWindow(window);

    std.log.debug("SDL Video Drivers: {s}:{d}", .{ c.SDL_GetCurrentVideoDriver(), c.SDL_GetNumVideoDrivers() });
    std.log.debug("SDL Audio Drivers: {s}:{d}", .{ c.SDL_GetCurrentAudioDriver(), c.SDL_GetNumAudioDrivers() });
    std.log.debug("SDL Render Drivers: {s}:{d}", .{ c.SDL_GetRendererName(renderer), c.SDL_GetNumRenderDrivers() });

    while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => return,
                else => std.log.debug("Event: {any}", .{event.type}),
            }
        }

        const brick_1: c.SDL_FRect = .{ .x = 50, .y = 1, .w = 32, .h = 32 };
        const brick_2: c.SDL_FRect = .{ .x = 1, .y = 50, .w = 32, .h = 32 };
        const brick_3: c.SDL_FRect = .{ .x = 100, .y = 1, .w = 32, .h = 32 };
        const brick_4: c.SDL_FRect = .{ .x = 1, .y = 100, .w = 32, .h = 32 };

        const rectangle = [_]c.SDL_FRect{
            brick_1,
            brick_2,
            brick_3,
            brick_4,
        };

        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff));
        try errify(c.SDL_RenderClear(renderer));
        try errify(c.SDL_RenderRect(renderer, rectangle[0..]));
        try errify(c.SDL_RenderPresent(renderer));
    }
}

/// Converts the return value of an SDL function to an error union.
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
