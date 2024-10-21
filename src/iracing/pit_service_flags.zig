pub const PitServiceFlags = enum(i16) {
    lf_tire_change = 0x01,
    rf_tire_change = 0x02,
    lr_tire_change = 0x04,
    rr_tire_change = 0x08,
    fuel_fill = 0x10,
    windshield_tearoff = 0x20,
    fast_repair = 0x40,
};
