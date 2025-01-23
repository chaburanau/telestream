const std = @import("std");

const source = @import("source.zig");
const header = @import("header.zig");

pub const Controller = struct {
    source: source.Source,

    last_header_version: i32,
    last_session_info_version: i32,

    last_header: header.Header,
    last_session_info: []u8,

    pub fn init(data_source: source.Source) Controller {
        return Controller{ .source = data_source };
    }

    pub fn getHeader(self: Controller) header.Header {
        return self.last_header;
    }

    pub fn getSessionInfo(self: Controller) []u8 {
        return self.last_session_info;
    }
};
