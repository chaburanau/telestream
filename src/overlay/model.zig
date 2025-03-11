const std = @import("std");

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const Position = struct {
    x: f32,
    y: f32,
};

pub const Size = struct {
    w: f32,
    h: f32,
};
