pub const PaceMode = enum(i16) {
    single_file_start = 0,
    double_file_start = 1,
    single_file_restart = 2,
    double_file_restart = 3,
    not_pacing = 4,
};
