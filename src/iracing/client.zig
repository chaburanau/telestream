const std = @import("std");
const mem = std.mem;
const heap = std.heap;
const http = std.http;

const model = @import("model.zig");
const source = @import("source.zig");
const mapper = @import("mapper.zig");
const events = @import("event.zig");
const session = @import("session.zig");

const SimError = error{
    SimNotRunning,
};

pub fn isRunning(allocator: mem.Allocator, url: []const u8) !bool {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const endpoint = url ++ "/get_sim_status?object=simStatus";
    const uri = try std.Uri.parse(endpoint);
    const headers_data: [64]u8 = undefined;
    const body_data: [256]u8 = undefined;

    var request = try client.open(.GET, uri, .{ .server_header_buffer = headers_data });
    defer request.deinit();

    try request.send();
    try request.finish();
    try request.wait();

    const body = try request.read(body_data);

    return mem.indexOf(u8, body, "running:1") != null;
}

const SIZE_HEADER = @sizeOf(model.Header);
const SIZE_VARIABLE = @sizeOf(model.Variable);
const TIMEOUT: u32 = 10000;

pub const Client = struct {
    allocator: mem.Allocator,

    source: source.Source,
    events: events.EventLoop,

    header_data: [SIZE_HEADER]u8,

    pub fn init(
        allocator: mem.Allocator,
        data_source: source.Source,
        events_loop: events.EventLoop,
    ) !Client {
        return Client{
            .allocator = allocator,
            .source = data_source,
            .events = events_loop,
            .header_data = undefined,
        };
    }

    pub fn run(self: *Client, updater: anytype) !void {
        while (true) {
            const close = try self.iteration(updater);
            if (close) return;
        }
    }

    fn iteration(self: *Client, updater: anytype) !bool {
        try self.events.wait(TIMEOUT);
        const header = try self.getHeader();

        var sessions = try self.getSession(header);
        defer sessions.deinit(self.allocator);

        var variables = try self.getVariables(header);
        defer variables.deinit(self.allocator);

        var values = try self.getValues(header, variables);
        defer values.deinit(self.allocator);

        return try updater.update(
            header,
            sessions,
            variables,
            values,
        );
    }

    pub fn getHeader(self: *Client) !model.Header {
        try self.source.read(0, &self.header_data);
        return try mapper.mapStruct(model.Header, &self.header_data);
    }

    pub fn getSession(self: *Client, header: model.Header) !model.Session {
        const offset: usize = @intCast(header.session_offset);
        const lenght: usize = @intCast(header.session_lenght);
        const data = try self.allocator.alloc(u8, lenght);
        defer self.allocator.free(data);
        try self.source.read(offset, data);

        return model.Session{
            .version = header.session_version,
            .info = try session.SessionInfo.init(self.allocator, data),
        };
    }

    pub fn getVariables(self: *Client, header: model.Header) !model.Variables {
        const offset: usize = @intCast(header.variables_offset);
        const lenght: usize = @intCast(header.number_of_variables * SIZE_VARIABLE);
        const data = try self.allocator.alloc(u8, lenght);
        defer self.allocator.free(data);
        try self.source.read(offset, data);

        return model.Variables{
            .items = try mapper.mapSlice(model.Variable, self.allocator, data),
        };
    }

    pub fn getValues(self: *Client, header: model.Header, variables: model.Variables) !model.Values {
        const buffer = self.getLastTick(header);
        const offset: usize = @intCast(buffer.offset);
        const lenght: usize = @intCast(header.buffers_length);
        const data = try self.allocator.alloc(u8, lenght);
        defer self.allocator.free(data);
        try self.source.read(offset, data);

        const values = try self.allocator.alloc(model.Value, variables.items.len);

        for (0..variables.items.len) |index| {
            const current_offset: usize = @intCast(variables.items[index].offset);
            const current_lenght: usize = @intCast(variables.items[index].size());

            const chunk = data[current_offset .. current_offset + current_lenght];
            values[index] = try model.Value.init(self.allocator, variables.items[index], chunk);
        }

        return model.Values{
            .buffer = buffer,
            .items = values,
        };
    }

    fn getLastTick(_: Client, header: model.Header) model.Buffer {
        var ticks = [4]i32{
            header.buffers[0].tick,
            header.buffers[1].tick,
            header.buffers[2].tick,
            header.buffers[3].tick,
        };

        std.mem.sort(i32, &ticks, {}, std.sort.desc(i32));

        for (0..4) |index| {
            if (header.buffers[index].tick == ticks[1]) {
                return header.buffers[index];
            }
        }

        unreachable;
    }
};
