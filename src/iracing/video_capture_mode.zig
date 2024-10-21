pub const VideoCaptureMode = enum(i16) {
    trigger_screen_shot = 0,
    start_video_capture = 1,
    end_video_capture = 2,
    toggle_video_capture = 3,
    show_video_timer = 4,
    hide_video_timer = 5,
};
