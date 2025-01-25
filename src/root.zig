const std = @import("std");
const testing = std.testing;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}
pub const scope_levels = [_]std.log.ScopeLevel{
    .{ .scope = .parse, .level = .crit},
};


test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
