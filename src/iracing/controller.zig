const std = @import("std");

const source = @import("source.zig");
const header = @import("header.zig");
const mapper = @import("mapper.zig");
const events = @import("event.zig");
const session = @import("session.zig");

const HEADER_SIZE = @sizeOf(header.Header);
const VARIABLE_SIZE = @sizeOf(header.ValueHeader);
const TIMEOUT: u32 = 10000;

pub const Controller = struct {
    allocator: std.mem.Allocator,

    source: source.Source,
    events: events.EventLoop,

    header: header.Header,
    header_data: [HEADER_SIZE]u8,

    session_info: ?session.SessionInfo,
    session_info_data: []u8,

    variables_headers: std.ArrayList(header.ValueHeader),
    variables_headers_data: []u8,

    variables_values: std.ArrayList(header.Value),
    variables_values_data: []u8,

    session_info_version: u64 = 0,
    variables_values_version: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, src: source.Source, evt: events.EventLoop) !Controller {
        return Controller{
            .allocator = allocator,
            .source = src,
            .events = evt,
            .header = std.mem.zeroes(header.Header),
            .header_data = std.mem.zeroes([HEADER_SIZE]u8),
            .session_info = null,
            .session_info_data = try allocator.alloc(u8, 1),
            .variables_headers = std.ArrayList(header.ValueHeader).init(allocator),
            .variables_headers_data = try allocator.alloc(u8, 1),
            .variables_values = std.ArrayList(header.Value).init(allocator),
            .variables_values_data = try allocator.alloc(u8, 1),
        };
    }

    pub fn deinit(self: *Controller) void {
        self.allocator.free(self.variables_values_data);
        self.allocator.free(self.variables_headers_data);
        self.allocator.free(self.session_info_data);

        self.variables_values.deinit();
        self.variables_headers.deinit();
        if (self.session_info) |*info| info.deinit();
    }

    pub fn run(self: *Controller, updater: anytype) !void {
        while (true) {
            try self.events.wait(TIMEOUT);
            try self.readHeader();
            try self.readSession();
            try self.readVariablesHeaders();
            try self.readVariablesValues();

            const close = try updater.update(
                self.header,
                self.session_info.?,
                self.variables_headers,
                self.variables_values,
            );

            if (close) return;
        }
    }

    fn readHeader(self: *Controller) !void {
        try self.source.read(0, &self.header_data);
        self.header = try mapper.mapStruct(header.Header, &self.header_data);
    }

    fn readSession(self: *Controller) !void {
        if (self.header.session_info_version <= self.session_info_version) return;

        self.session_info_version = @intCast(self.header.session_info_version);
        const offset: usize = @intCast(self.header.session_info_offset);
        const size: usize = @intCast(self.header.session_info_lenght);

        self.allocator.free(self.session_info_data);
        self.session_info_data = try self.allocator.alloc(u8, size);
        try self.source.read(offset, self.session_info_data);

        if (self.session_info) |*info| info.deinit();
        self.session_info = try session.SessionInfo.init(self.allocator, self.session_info_data);
    }

    fn readVariablesHeaders(self: *Controller) !void {
        if (self.variables_headers.items.len > 0) return;

        const offset: usize = @intCast(self.header.value_header_offset);
        const count: usize = @intCast(self.header.number_of_values);
        const size: usize = @intCast(count * VARIABLE_SIZE);

        self.allocator.free(self.variables_headers_data);
        self.variables_headers_data = try self.allocator.alloc(u8, size);

        try self.variables_headers.resize(count);
        try self.source.read(offset, self.variables_headers_data);
        try mapper.mapArray(header.ValueHeader, &self.variables_headers, self.variables_headers_data, count);
    }

    fn readVariablesValues(self: *Controller) !void {
        const buffer = self.getLastBuffer();
        if (buffer.tick <= self.variables_values_version) return;

        self.variables_values_version = @intCast(buffer.tick);
        const offset: usize = @intCast(buffer.offset);
        const count: usize = @intCast(self.header.number_of_values);
        const size: usize = self.variablesTotalSize();

        self.allocator.free(self.variables_values_data);
        self.variables_values_data = try self.allocator.alloc(u8, size);

        try self.variables_values.resize(count);
        try self.source.read(offset, self.variables_values_data);
        for (0..count) |index| {
            const head = self.variables_headers.items[index];
            const start: usize = @intCast(head.offset);
            const end: usize = start + head.size();
            const chunk = self.variables_values_data[start..end];
            self.variables_values.items[index] = header.Value{
                .data = chunk,
                .type = head.value_type,
                .count = @intCast(head.count),
            };
        }
    }

    fn getLastBuffer(self: *Controller) header.Buffer {
        std.mem.sort(header.Buffer, &self.header.buffers, {}, header.Buffer.less);
        return self.header.buffers[1];
    }

    fn variablesTotalSize(self: *Controller) usize {
        var last: usize = 0;

        for (1..self.variables_headers.items.len) |index| {
            const current_header = self.variables_headers.items[index];
            const last_header = self.variables_headers.items[last];

            if (current_header.offset > last_header.offset) {
                last = index;
            }
        }

        const last_header = self.variables_headers.items[last];
        const offset: usize = @intCast(last_header.offset);
        return offset + last_header.size();
    }
};
