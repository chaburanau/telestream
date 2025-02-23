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

    last_session_info_version: u64 = 0,
    last_session_info_offset: usize = 0,
    last_session_info_data: std.ArrayList(u8),
    last_session_info: ?session.SessionInfo = null,

    last_variables_version: u64 = 0,
    last_variables_offset: usize = 0,
    last_variables_data: std.ArrayList(u8),
    last_variables: ?std.ArrayList(header.ValueHeader) = null,

    pub fn init(
        allocator: std.mem.Allocator,
        data_source: source.Source,
        event_loop: events.EventLoop,
    ) !Controller {
        return Controller{
            .allocator = allocator,
            .source = data_source,
            .events = event_loop,
            .last_header_data = std.mem.zeroes([HEADER_SIZE]u8),
            .last_header = std.mem.zeroes(header.Header),
            .last_session_info_data = std.ArrayList(u8).init(allocator),
            .last_variables_data = std.ArrayList(u8).init(allocator),
            .last_variables = std.ArrayList(header.ValueHeader).init(allocator),
        };
    }

    pub fn deinit(self: *Controller) void {
        self.last_session_info_data.deinit();
        self.last_variables_data.deinit();
        if (self.last_session_info) |*info| info.deinit();
        if (self.last_variables) |*variables| variables.deinit();
    }

    pub fn getHeader(self: *Controller) !header.Header {
        try self.updateHeader();
        return self.last_header;
    }

    pub fn getSessionInfo(self: *Controller) !session.SessionInfo {
        try self.updateHeader();
        if (self.readyForSessionInfoUpdate()) try self.updateSessionInfo();
        return self.last_session_info.?;
    }

    pub fn getVariables(self: *Controller) !std.ArrayList(header.ValueHeader) {
        try self.updateHeader();
        if (self.readyForVariablesUpdate()) try self.updateVariables();
        return self.last_variables.?;
    }

    fn updateHeader(self: *Controller) !void {
        try self.source.read(0, &self.last_header_data);
        self.last_header = try mapper.mapStruct(header.Header, &self.last_header_data);
    }

    fn updateSessionInfo(self: *Controller) !void {
        const size: usize = @intCast(self.last_header.session_info_lenght);

        try Controller.resize(u8, &self.last_session_info_data, size);
        try self.source.read(self.last_session_info_offset, self.last_session_info_data.items);
        self.last_session_info = try session.SessionInfo.init(self.allocator, self.last_session_info_data.items);
    }

    fn updateVariables(self: *Controller) !void {
        const count: usize = @intCast(self.last_header.n_vars);
        const size: usize = @intCast(count * VARIABLE_SIZE);

        try Controller.resize(u8, &self.last_variables_data, size);
        try Controller.resize(header.ValueHeader, &self.last_variables.?, count);
        try self.source.read(self.last_variables_offset, self.last_variables_data.items);
        for (0..count) |index| {
            const chunk = self.last_variables_data.items[index * VARIABLE_SIZE .. (index + 1) * VARIABLE_SIZE];
            const value = try mapper.mapStruct(header.ValueHeader, chunk);
            self.last_variables.?.items[index] = value;
        }
    }

    fn readyForSessionInfoUpdate(self: *Controller) bool {
        if (self.last_header.session_info_version > self.last_session_info_version) {
            self.last_session_info_version = @intCast(self.last_header.session_info_version);
            self.last_session_info_offset = @intCast(self.last_header.session_info_offset);
            return true;
        }

        return false;
    }

    fn readyForVariablesUpdate(self: *Controller) bool {
        var found = false;

        for (self.last_header.buffers) |buffer| {
            if (buffer.ticks > self.last_variables_version) {
                self.last_variables_version = @intCast(buffer.ticks);
                self.last_variables_offset = @intCast(buffer.offset);
                found = true;
            }
        }

        return found;
    }

    fn resize(comptime T: type, array: *std.ArrayList(T), size: usize) !void {
        if (array.capacity > size) array.shrinkAndFree(size);
        if (array.capacity < size) try array.ensureTotalCapacity(size);
        if (array.items.len < size) try array.appendNTimes(std.mem.zeroes(T), size - array.items.len);
    }
};
