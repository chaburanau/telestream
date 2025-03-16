const std = @import("std");
const session = @import("session.zig");

pub const Header = extern struct {
    version: i32,
    state: State,
    tick_rate: i32,
    session_version: i32,
    session_lenght: i32,
    session_offset: i32,
    number_of_variables: i32,
    variables_offset: i32,
    number_of_buffers: i32,
    buffers_length: i32,
    padding: [2]u32,
    buffers: [4]Buffer,

    pub fn lastBuffer(self: Header) Buffer {
        const buffers = self.buffers;
        var ticks = [4]i32{
            buffers[0].tick,
            buffers[1].tick,
            buffers[2].tick,
            buffers[3].tick,
        };

        std.mem.sort(i32, &ticks, {}, std.sort.desc(i32));

        for (0..4) |index| {
            if (ticks[1] == buffers[index].tick) {
                return buffers[index];
            }
        }

        unreachable;
    }
};

pub const Buffer = extern struct {
    tick: i32,
    offset: i32,
    padding: [2]u32,

    pub fn more(_: void, left: Buffer, right: Buffer) bool {
        return left.tick > right.tick;
    }
};

pub const VariableType = enum(i32) {
    char = 0,
    bool = 1,
    int = 2,
    bitfield = 3,
    float = 4,
    double = 5,
    count = 6,

    pub fn size(self: VariableType) usize {
        return switch (self) {
            .char, .bool => 1,
            .int, .bitfield, .float => 4,
            .double, .count => 8,
        };
    }

    pub fn Type(self: VariableType) type {
        return switch (self) {
            .char => u8,
            .bool => bool,
            .int => i32,
            .bitfield => i32,
            .float => f32,
            .double => f64,
            .count => i64,
        };
    }
};

pub const Variable = extern struct {
    type: VariableType,
    offset: i32,
    count: i32,
    count_as_time: bool,

    padding: [3]u8,
    name: [32]u8,
    desc: [64]u8,
    unit: [32]u8,

    pub fn size(self: Variable) usize {
        const count: usize = @intCast(self.count);
        return self.type.size() * count;
    }

    pub fn isArray(self: Variable) bool {
        return self.count > 1;
    }
};

pub const Value = union(enum) {
    char: u8,
    chars: []u8,
    bool: bool,
    bools: []bool,
    int: i32,
    ints: []i32,
    bitfield: i32,
    bitfields: []i32,
    float: f32,
    floats: []f32,
    double: f64,
    doubles: []f64,
    count: i64,
    counts: []i64,

    pub fn init(allocator: std.mem.Allocator, variable: Variable, data: []u8) !Value {
        const count: usize = @intCast(variable.count);
        const is_array = variable.isArray();

        return switch (variable.type) {
            .char => {
                if (is_array) return Value{ .chars = try Value.multi(u8, allocator, data, count) };
                return Value{ .char = try Value.single(u8, data) };
            },
            .bool => {
                if (is_array) return Value{ .bools = try Value.multi(bool, allocator, data, count) };
                return Value{ .bool = try Value.single(bool, data) };
            },
            .int => {
                if (is_array) return Value{ .ints = try Value.multi(i32, allocator, data, count) };
                return Value{ .int = try Value.single(i32, data) };
            },
            .bitfield => {
                if (is_array) return Value{ .bitfields = try Value.multi(i32, allocator, data, count) };
                return Value{ .bitfield = try Value.single(i32, data) };
            },
            .float => {
                if (is_array) return Value{ .floats = try Value.multi(f32, allocator, data, count) };
                return Value{ .float = try Value.single(f32, data) };
            },
            .double => {
                if (is_array) return Value{ .doubles = try Value.multi(f64, allocator, data, count) };
                return Value{ .double = try Value.single(f64, data) };
            },
            .count => {
                if (is_array) return Value{ .counts = try Value.multi(i64, allocator, data, count) };
                return Value{ .count = try Value.single(i64, data) };
            },
        };
    }

    pub fn deinit(self: Value, allocator: std.mem.Allocator) void {
        switch (self) {
            .chars => |cap| allocator.free(cap),
            .bools => |cap| allocator.free(cap),
            .ints => |cap| allocator.free(cap),
            .bitfields => |cap| allocator.free(cap),
            .floats => |cap| allocator.free(cap),
            .doubles => |cap| allocator.free(cap),
            .counts => |cap| allocator.free(cap),
            else => {},
        }
    }

    fn single(comptime T: type, data: []const u8) !T {
        return switch (T) {
            u8 => data[0],
            bool => data[0] > 0,
            i32 => std.mem.bytesToValue(i32, data),
            f32 => std.mem.bytesToValue(f32, data),
            i64 => std.mem.bytesToValue(i64, data),
            f64 => std.mem.bytesToValue(f64, data),
            else => unreachable,
        };
    }

    fn multi(comptime T: type, allocator: std.mem.Allocator, data: []u8, count: usize) ![]T {
        const size = @sizeOf(T);
        var array = try allocator.alloc(T, count);

        for (0..count) |index| {
            const chunk = data[index * size .. (index + 1) * size];
            array[index] = try Value.single(T, chunk);
        }

        return array;
    }
};

pub const Session = struct {
    version: i32,
    info: session.SessionInfo,

    pub fn deinit(self: *Session, allocator: std.mem.Allocator) void {
        self.info.deinit(allocator);
    }
};

pub const Variables = struct {
    items: []Variable,

    pub fn deinit(self: *Variables, allocator: std.mem.Allocator) void {
        allocator.free(self.items);
    }
};

pub const Values = struct {
    buffer: Buffer,
    items: []Value,

    pub fn deinit(self: *Values, allocator: std.mem.Allocator) void {
        for (0..self.items.len) |index| self.items[index].deinit(allocator);
        allocator.free(self.items);
    }
};

pub const BroadcastMessages = enum(i16) {
    cam_switch_pos = 0,
    cam_switch_num = 1,
    cam_set_state = 2,
    replay_set_play_speed = 3,
    replay_set_play_position = 4,
    replay_search = 5,
    replay_set_state = 6,
    reload_textures = 7,
    chat_command = 8,
    pit_command = 9,
    telem_command = 10,
    ffb_command = 11,
    replay_search_session_time = 12,
    video_capture = 13,
};

pub const CameraState = enum(i16) {
    is_session_screen = 1,
    is_scenic_active = 2,

    cam_tool_active = 4,
    ui_hidden = 8,
    use_auto_shot_selection = 16,
    use_temporary_edits = 32,
    use_key_acceleration = 64,
    use_key10x_acceleration = 128,
    use_mouse_aim_mode = 256,
};

pub const CameraStateMode = enum(i16) {
    at_incident = -3,
    at_leader = -2,
    at_exciting = -1,
};

pub const CarSpotter = enum(i16) {
    off = 0,
    clear = 1,
    car_left = 2,
    car_right = 3,
    car_left_right = 4,
    two_cars_left = 5,
    two_cars_right = 6,
};

pub const ChatMacro = enum(i16) {
    macro = 0,
    begin_chat = 1,
    reply = 2,
    cancel = 3,
};

pub const Flags = enum(i16) {
    // global flags
    checkered = 0x0001,
    white = 0x0002,
    green = 0x0004,
    yellow = 0x0008,
    red = 0x0010,
    blue = 0x0020,
    debris = 0x0040,
    crossed = 0x0080,
    yellow_waving = 0x0100,
    one_lap_to_green = 0x0200,
    green_held = 0x0400,
    ten_to_go = 0x0800,
    five_to_go = 0x1000,
    random_waving = 0x2000,
    caution = 0x4000,
    caution_waving = 0x8000,

    // drivers black flags
    black = 0x010000,
    disqualify = 0x020000,
    servicible = 0x040000,
    furled = 0x080000,
    repair = 0x100000,

    // start lights
    start_hidden = 0x10000000,
    start_ready = 0x20000000,
    start_set = 0x40000000,
    start_go = 0x80000000,
};

pub const ForceFeedbackCommandMode = enum(i16) {
    ffb_command_max_force = 0,
};

pub const PaceFlags = enum(i16) {
    end_of_line = 0x0001,
    free_pass = 0x0002,
    waved_around = 0x0004,
};

pub const PaceMode = enum(i16) {
    single_file_start = 0,
    double_file_start = 1,
    single_file_restart = 2,
    double_file_restart = 3,
    not_pacing = 4,
};

pub const PitCommandMode = enum(i16) {
    clear = 0,
    ws = 1,
    fuel = 2,
    lf = 3,
    rf = 4,
    lr = 5,
    rr = 6,
    clear_tires = 7,
    fr = 8,
    clear_ws = 9,
    clear_fr = 10,
    clear_fuel = 11,
};

pub const PitServiceFlags = enum(i16) {
    lf_tire_change = 0x01,
    rf_tire_change = 0x02,
    lr_tire_change = 0x04,
    rr_tire_change = 0x08,
    fuel_fill = 0x10,
    windshield_tearoff = 0x20,
    fast_repair = 0x40,
};

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

pub const ReloadTexturesMode = enum(i16) {
    all = 0,
    car_idx = 1,
};

pub const ReplayPositionMode = enum(i16) {
    begin = 0,
    current = 1,
    end = 2,
};

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

pub const ReplayStateMode = enum(i16) {
    erase_tape = 0,
};

pub const State = enum(i32) {
    invalid = 0,
    get_in_car = 1,
    warmup = 2,
    parade_laps = 3,
    racing = 4,
    checkered = 5,
    cool_down = 6,
};

pub const TelemetryCommandMode = enum(i16) {
    stop = 0,
    start = 1,
    restart = 2,
};

pub const TrackPosition = enum(i16) {
    not_in_world = -1,
    off_track = 0,
    in_pit_stall = 1,
    aproaching_pits = 2,
    on_track = 3,
};

pub const TrackSurface = enum(i16) {
    not_in_world = -1,
    undefined = 0,
    asphalt_1 = 1,
    asphalt_2 = 2,
    asphalt_3 = 3,
    asphalt_4 = 4,
    concrete_1 = 5,
    concrete_2 = 6,
    racing_dirt_1 = 7,
    racing_dirt_2 = 8,
    paint_1 = 9,
    paint_2 = 10,
    rumble_1 = 11,
    rumble_2 = 12,
    rumble_3 = 13,
    rumble_4 = 14,
    grass_1 = 15,
    grass_2 = 16,
    grass_3 = 17,
    grass_4 = 18,
    dirt_1 = 19,
    dirt_2 = 20,
    dirt_3 = 21,
    dirt_4 = 22,
    sand = 23,
    gravel_1 = 24,
    gravel_2 = 25,
    grasscrete = 26,
    astroturf = 27,
};

pub const TrackWetness = enum(i16) {
    unknown = 0,
    dry = 1,
    mostly_dry = 2,
    very_lightly_wet = 3,
    lightly_wet = 4,
    moderately_wet = 5,
    very_wet = 6,
    extremely_wet = 7,
};

pub const VideoCaptureMode = enum(i16) {
    trigger_screen_shot = 0,
    start_video_capture = 1,
    end_video_capture = 2,
    toggle_video_capture = 3,
    show_video_timer = 4,
    hide_video_timer = 5,
};

pub const EngineWarning = enum(i16) {
    water_temp_warning = 0x01,
    fuel_pressure_warning = 0x02,
    oil_pressure_warning = 0x04,
    engine_stalled = 0x08,
    pit_speed_limiter = 0x010,
    rev_limiter_active = 0x020,
    oil_temp_warning = 0x040,
};
