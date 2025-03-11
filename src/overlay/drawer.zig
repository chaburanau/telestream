const std = @import("std");
const model = @import("model.zig");
const errors = @import("errors.zig");

const c = @cImport({
    @cInclude("windows.h");
    @cInclude("SDL3/SDL.h");
});

pub const Drawer = struct {
    renderer: ?*c.SDL_Renderer = null,

    pub fn init(renderer: ?*c.SDL_Renderer) Drawer {
        return Drawer{ .renderer = renderer };
    }

    pub fn drawRectange(self: *Drawer, position: model.Position, size: model.Size, color: model.Color) !void {
        const rects = [_]c.SDL_FRect{.{ .x = position.x, .y = position.y, .w = size.w, .h = size.h }};
        try errors.errify(c.SDL_SetRenderDrawColor(self.renderer, color.r, color.g, color.b, color.a));
        try errors.errify(c.SDL_RenderRect(self.renderer, rects[0..]));
    }

    pub fn drawText(self: *Drawer, text: []const u8, position: model.Position, color: model.Color) !void {
        try errors.errify(c.SDL_SetRenderDrawColor(self.renderer, color.r, color.g, color.b, color.a));
        try errors.errify(c.SDL_RenderDebugText(self.renderer, position.x, position.y, text.ptr));
    }
};
