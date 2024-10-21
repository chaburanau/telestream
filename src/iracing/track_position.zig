pub const TrackPosition = enum(i16) {
    not_in_world = -1,
    off_track = 0,
    in_pit_stall = 1,
    aproaching_pits = 2,
    on_track = 3,
};
