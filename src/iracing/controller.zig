const std = @import("std");

const source = @import("source.zig");
const header = @import("header.zig");
const mapper = @import("mapper.zig");
const events = @import("event.zig");
const session = @import("session.zig");

const HEADER_SIZE = @sizeOf(header.Header);
const VARIABLE_SIZE = @sizeOf(header.ValueHeader);

pub const Controller = struct {
    allocator: std.mem.Allocator,

    source: source.Source,
    events: events.EventLoop,

    last_header_data: [HEADER_SIZE]u8,
    last_header: header.Header,

    variables_header_data: std.ArrayList(u8),
    variables_header: ?std.ArrayList(header.ValueHeader) = null,

    last_session_info_version: u64 = 0,
    last_session_info_offset: usize = 0,
    last_session_info_data: std.ArrayList(u8),
    last_session_info: ?session.SessionInfo = null,

    last_variables_version: u64 = 0,
    last_variables_offset: usize = 0,
    last_variables_data: std.ArrayList(u8),
    last_variables: ?std.ArrayList(header.Variable) = null,

    pub fn init(allocator: std.mem.Allocator, src: source.Source, evt: events.EventLoop) !Controller {
        return Controller{
            .allocator = allocator,
            .source = src,
            .events = evt,
            .last_header_data = std.mem.zeroes([HEADER_SIZE]u8),
            .last_header = std.mem.zeroes(header.Header),
            .variables_header_data = std.ArrayList(u8).init(allocator),
            .variables_header = std.ArrayList(header.ValueHeader).init(allocator),
            .last_session_info_data = std.ArrayList(u8).init(allocator),
            .last_variables_data = std.ArrayList(u8).init(allocator),
            .last_variables = std.ArrayList(header.Variable).init(allocator),
        };
    }

    pub fn deinit(self: *Controller) void {
        self.variables_header_data.deinit();
        self.last_session_info_data.deinit();
        self.last_variables_data.deinit();
        if (self.variables_header) |*head| head.deinit();
        if (self.last_session_info) |*info| info.deinit();
        if (self.last_variables) |*vars| vars.deinit();
    }

    pub fn start(self: *Controller, updater: anytype) !void {
        while (true) {
            try self.events.wait(10000);
            try self.readHeader();
            try self.readSession();
            try self.readVariablesHeader();
            try self.readVariables();

            const close = try updater.update(
                self.last_header,
                self.last_session_info.?,
                self.variables_header.?,
                self.last_variables.?,
            );

            if (close) return;
        }
    }

    fn readHeader(self: *Controller) !void {
        try self.source.read(0, &self.last_header_data);
        self.last_header = try mapper.mapStruct(header.Header, &self.last_header_data);
    }

    fn readSession(self: *Controller) !void {
        if (self.last_header.session_info_version <= self.last_session_info_version) return;

        self.last_session_info_version = @intCast(self.last_header.session_info_version);
        self.last_session_info_offset = @intCast(self.last_header.session_info_offset);

        try Controller.resize(u8, &self.last_session_info_data, 0, @intCast(self.last_header.session_info_lenght));
        try self.source.read(self.last_session_info_offset, self.last_session_info_data.items);

        if (self.last_session_info) |*info| info.deinit();
        self.last_session_info = try session.SessionInfo.init(self.allocator, self.last_session_info_data.items);
    }

    fn readVariablesHeader(self: *Controller) !void {
        if (self.variables_header.?.items.len > 0) return;

        const count: usize = @intCast(self.last_header.n_vars);
        const size: usize = @intCast(count * VARIABLE_SIZE);
        const offset: usize = @intCast(self.last_header.header_offset);

        try Controller.resize(u8, &self.variables_header_data, 0, size);
        try Controller.resize(header.ValueHeader, &self.variables_header.?, std.mem.zeroes(header.ValueHeader), count);
        try self.source.read(offset, self.variables_header_data.items);
        for (0..count) |index| {
            const chunk = self.variables_header_data.items[index * VARIABLE_SIZE .. (index + 1) * VARIABLE_SIZE];
            const value = try mapper.mapStruct(header.ValueHeader, chunk);
            self.variables_header.?.items[index] = value;
        }
    }

    fn readVariables(self: *Controller) !void {
        if (!self.readyForVariablesUpdate()) return;

        const count: usize = @intCast(self.variables_header.?.items.len);
        const size: usize = self.variablesTotalSize();

        try Controller.resize(u8, &self.last_variables_data, 0, size);
        try Controller.resize(header.Variable, &self.last_variables.?, header.Variable{}, count);
        try self.source.read(self.last_variables_offset, self.last_variables_data.items);
        for (0..count) |index| {
            const head = self.variables_header.?.items[index];
            const offset: usize = @intCast(head.offset);
            const chunk = self.last_variables_data.items[offset .. offset + head.size()];
            const value = try header.Value.init(self.allocator, head, chunk);
            self.last_variables.?.items[index] = header.Variable{
                .name = head._name,
                .unit = head._unit,
                .value = value,
            };
        }
    }

    fn readyForVariablesUpdate(self: *Controller) bool {
        var last_version: usize = 0;
        var last_offset: usize = 0;
        var before_last_version: usize = 0;
        var before_last_offset: usize = 0;

        for (self.last_header.buffers) |buffer| {
            if (buffer.ticks > last_version) {
                before_last_version = last_version;
                before_last_offset = last_offset;
                last_version = @intCast(buffer.ticks);
                last_offset = @intCast(buffer.offset);
            }
        }

        if (before_last_version > self.last_variables_version) {
            self.last_variables_version = before_last_version;
            self.last_variables_offset = before_last_offset;
            return true;
        }

        return false;
    }

    fn variablesTotalSize(self: *Controller) usize {
        var last: header.ValueHeader = self.variables_header.?.items[0];

        for (self.variables_header.?.items[1..]) |variable| {
            if (variable.offset > last.offset) {
                last = variable;
            }
        }

        const offset: usize = @intCast(last.offset);
        return offset + last.size();
    }

    fn resize(comptime T: type, array: *std.ArrayList(T), default: T, size: usize) !void {
        if (array.capacity > size) array.shrinkAndFree(size);
        if (array.capacity < size) try array.ensureTotalCapacity(size);
        if (array.items.len < size) try array.appendNTimes(default, size - array.items.len);
    }
};
