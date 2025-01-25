const std = @import("std");
const yaml = @import("yaml");

pub const ParsingError = error{
    KeyNotFound,
    IndexOutOfRange,
    InvalidType,
};

pub const SessionInfo = struct {
    session_info: yaml.Yaml,

    pub fn init(allocator: std.mem.Allocator, data: []const u8) !SessionInfo {
        const session_info = try yaml.Yaml.load(allocator, data);
        return SessionInfo{ .session_info = session_info };
    }

    pub fn deinit(self: *SessionInfo) void {
        self.session_info.deinit();
    }

    pub fn keys(self: SessionInfo) [][]const u8 {
        return self.session_info.docs.items[0].map.keys();
    }

    pub fn get(self: SessionInfo, T: type, path: []const u8) !T {
        var split = std.mem.splitScalar(u8, path, '.');
        var current = self.session_info.docs.items[0];
        while (split.next()) |item| {
            std.debug.print("item: {s}\n", .{item});
            switch (current) {
                .map => {
                    std.debug.print("keys: {s}\n", .{current.map.keys()});
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
