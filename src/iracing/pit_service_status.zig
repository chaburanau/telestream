pub const PitServiceStatus = enum(i16) {
    none = 0,
    in_progress = 1,
    complete = 2,

    too_far_left = 100,
    too_far_right = 101,
    too_far_forward = 102,
    too_far_back = 103,
    bad_angle = 104,
    cant_fix_that = 105,
};
