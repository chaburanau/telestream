pub const SessionState = enum(i16) {
    invalid = 0,
    get_in_car = 1,
    warmup = 2,
    parade_laps = 3,
    racing = 4,
    checkered = 5,
    cool_down = 6,
};
