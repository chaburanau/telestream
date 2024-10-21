pub const EngineWarning = enum(i16) {
    water_temp_warning = 0x01,
    fuel_pressure_warning = 0x02,
    oil_pressure_warning = 0x04,
    engine_stalled = 0x08,
    pit_speed_limiter = 0x010,
    rev_limiter_active = 0x020,
    oil_temp_warning = 0x040,
};
