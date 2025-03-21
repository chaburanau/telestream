const std = @import("std");
const model = @import("model.zig");

pub const Black = model.Color{
    .r = 0,
    .g = 0,
    .b = 0,
    .a = 255,
};

pub const White = model.Color{
    .r = 255,
    .g = 255,
    .b = 255,
    .a = 255,
};

pub const Red = model.Color{
    .r = 255,
    .g = 0,
    .b = 0,
    .a = 255,
};

pub const Green = model.Color{
    .r = 0,
    .g = 255,
    .b = 0,
    .a = 255,
};

pub const Blue = model.Color{
    .r = 0,
    .g = 0,
    .b = 255,
    .a = 255,
};

pub const Yellow = model.Color{
    .r = 255,
    .g = 255,
    .b = 0,
    .a = 255,
};
