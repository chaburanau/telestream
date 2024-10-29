pub const SessionDetails = struct {
    WeekendInfo: WeekendInfo,
    SessionInfo: SessionInfo,
    CameraInfo: CameraInfo,
    RadioInfo: RadioInfo,
    DriverInfo: DriverInfo,
    SplitTimeInfo: SplitTimeInfo,
    CarSetup: CarSetup,
};

pub const WeekendInfo = struct {
    TrackName: []u8,
    TrackID: i32,
    TrackLenght: []u8,
    TrackLengthOfficial: []u8,
    TrackDisplayName: []u8,
    TrackDisplayShortName: []u8,
    TrackConfigName: []u8,
    TrackCity: []u8,
    TrackCountry: []u8,
    TrackAltitude: []u8,
};
pub const SessionInfo = struct {};
pub const CameraInfo = struct {};
pub const RadioInfo = struct {};
pub const DriverInfo = struct {};
pub const SplitTimeInfo = struct {};
pub const CarSetup = struct {};
