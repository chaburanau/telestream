pub const ReplaySearchMode = enum(i16) {
    to_start = 0,
    to_end = 1,
    prev_session = 2,
    next_session = 3,
    prev_lap = 4,
    next_lap = 5,
    prev_frame = 6,
    next_frame = 7,
    prev_incident = 8,
    next_incident = 9,
};
