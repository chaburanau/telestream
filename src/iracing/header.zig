const std = @import("std");

pub const Header = extern struct {
    version: i32,
    status: i32,
    tick_rate: i32,
    session_info_version: i32,
    session_info_lenght: i32,
    session_info_offset: i32,
    n_vars: i32,
    header_offset: i32,
    n_buffers: i32,
    buffer_length: i32,
    padding: [2]u32,
    buffers: [4]ValueBuffer,
};

pub const ValueBuffer = extern struct {
    ticks: i32,
    offset: i32,
    padding: [2]u32,
};

pub const ValueHeader = extern struct {
    value_type: i32,
    offset: i32,
    count: i32,
    count_as_time: bool,

    _pad: [3]u8,
    _name: [32]u8,
    _desc: [64]u8,
    _unit: [32]u8,
};

pub const Tick = extern struct {
    number: i32,
    buffer: []u8,
    values: []ValueHeader,
};

// Header: iracing.header.Header{ .version = 2, .status = 1, .tick_rate = 60, .session_info_version = 70, .session_info_lenght = 524288, .session_info_offset = 112, .n_vars = 324, .header_offset = 524400, .n_buffers = 3, .buffer_length = 7789, .padding = { 0, 0 }, .buffers = { iracing.header.ValueBuffer{ .ticks = 232896, .offset = 1114224, .padding = { ... } }, iracing.header.ValueBuffer{ .ticks = 232897, .offset = 1138800, .padding = { ... } }, iracing.header.ValueBuffer{ .ticks = 232895, .offset = 1163376, .padding = { ... } }, iracing.header.ValueBuffer{ .ticks = 0, .offset = 0, .padding = { ... } } } }
