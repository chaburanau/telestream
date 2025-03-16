const std = @import("std");
const yaml = @import("yaml");

pub const ParsingError = error{
    KeyNotFound,
    InvalidType,
    IndexOutOfRange,
};

pub const SessionInfo = struct {
    session_info: yaml.Yaml,

    pub fn init(allocator: std.mem.Allocator, data: []const u8) !SessionInfo {
        var parser = yaml.Yaml{ .source = data };
        try parser.load(allocator);

        return SessionInfo{
            .session_info = parser,
        };
    }

    pub fn deinit(self: *SessionInfo, allocator: std.mem.Allocator) void {
        self.session_info.deinit(allocator);
    }

    pub fn stringify(self: SessionInfo, writer: anytype) !void {
        try self.session_info.stringify(writer);
    }

    pub fn keys(self: SessionInfo) [][]const u8 {
        return self.session_info.docs.items[0].map.keys();
    }

    pub fn get(self: SessionInfo, T: type, path: []const u8) !T {
        var split = std.mem.splitScalar(u8, path, '.');
        var current = self.session_info.docs.items[0];
        while (split.next()) |item| {
            switch (current) {
                .map => {
                    if (current.map.get(item)) |next| {
                        current = next;
                    } else {
                        return ParsingError.KeyNotFound;
                    }
                },
                .list => {
                    const index = try std.fmt.parseInt(usize, item, 10);
                    if (current.list.len > index) {
                        current = current.list[index];
                    } else {
                        return ParsingError.IndexOutOfRange;
                    }
                },
                else => return ParsingError.KeyNotFound,
            }
        }

        switch (current) {
            .int => |int| {
                if (T == i64) {
                    return int;
                } else {
                    return ParsingError.InvalidType;
                }
            },
            .float => |float| {
                if (T == f64) {
                    return float;
                } else {
                    return ParsingError.InvalidType;
                }
            },
            .boolean => |boolean| {
                if (T == bool) {
                    return boolean;
                } else {
                    return ParsingError.InvalidType;
                }
            },
            .string => |string| {
                if (T == []const u8) {
                    return string;
                } else {
                    return ParsingError.InvalidType;
                }
            },
            else => {
                return ParsingError.InvalidType;
            },
        }
    }
};
