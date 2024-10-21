pub const CameraState = enum(i16) {
    is_session_screen = 0x0001,
    is_scenic_active = 0x0002,

    cam_tool_active = 0x0004,
    ui_hidden = 0x0008,
    use_auto_shot_selection = 0x0010,
    use_temporary_edits = 0x0020,
    use_key_acceleration = 0x0040,
    use_key10x_acceleration = 0x0080,
    use_mouse_aim_mode = 0x0100,
};
