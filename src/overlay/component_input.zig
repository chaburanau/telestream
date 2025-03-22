const std = @import("std");
const model = @import("model.zig");
const draw = @import("drawer.zig");
const colors = @import("colors.zig");

const iracing_sdk = @import("../iracing/client.zig");

pub const ComponentInput = struct {
    scale: f32,
    size: model.Size,
    position: model.Position,

    clutch: f32,
    brake: f32,
    throttle: f32,

    pub fn render(self: ComponentInput, drawer: *draw.Drawer) !void {
        const background_rectangle = model.Rectangle{
            .size = model.Size{
                .h = self.size.h * self.scale,
                .w = self.size.w * self.scale,
            },
            .position = model.Position{
                .x = self.position.x,
                .y = self.position.y,
            },
        };

        const block_height = background_rectangle.size.h / 10;
        const block_width = background_rectangle.size.w / 10;
        const bar_height = block_height * 8;
        const bar_width = block_width * 2;
        const bar_y = self.position.y + block_height;

        const clutch_height = bar_height * self.clutch;
        const brake_height = bar_height * self.brake;
        const throttle_height = bar_height * self.throttle;

        const clutch_bar_rectange = model.Rectangle{
            .size = model.Size{
                .h = bar_height,
                .w = bar_width,
            },
            .position = model.Position{
                .x = self.position.x + (1 * block_width),
                .y = bar_y,
            },
        };
        const brake_bar_rectange = model.Rectangle{
            .size = model.Size{
                .h = bar_height,
                .w = bar_width,
            },
            .position = model.Position{
                .x = self.position.x + (4 * block_width),
                .y = bar_y,
            },
        };
        const throttle_bar_rectange = model.Rectangle{
            .size = model.Size{
                .h = bar_height,
                .w = bar_width,
            },
            .position = model.Position{
                .x = self.position.x + (7 * block_width),
                .y = bar_y,
            },
        };

        const clutch_rectange = model.Rectangle{
            .size = model.Size{
                .h = clutch_height,
                .w = bar_width,
            },
            .position = model.Position{
                .x = clutch_bar_rectange.position.x,
                .y = self.position.y + block_height + bar_height - clutch_height,
            },
        };
        const brake_rectange = model.Rectangle{
            .size = model.Size{
                .h = brake_height,
                .w = bar_width,
            },
            .position = model.Position{
                .x = brake_bar_rectange.position.x,
                .y = self.position.y + block_height + bar_height - brake_height,
            },
        };
        const throttle_rectange = model.Rectangle{
            .size = model.Size{
                .h = throttle_height,
                .w = bar_width,
            },
            .position = model.Position{
                .x = throttle_bar_rectange.position.x,
                .y = self.position.y + block_height + bar_height - throttle_height,
            },
        };

        try drawer.drawRectangle(background_rectangle, colors.LightBlack, colors.LightBlack);

        try drawer.drawRectangle(clutch_bar_rectange, colors.Black, colors.Black);
        try drawer.drawRectangle(brake_bar_rectange, colors.Black, colors.Black);
        try drawer.drawRectangle(throttle_bar_rectange, colors.Black, colors.Black);

        try drawer.drawRectangle(clutch_rectange, colors.Blue, colors.Blue);
        try drawer.drawRectangle(brake_rectange, colors.Red, colors.Red);
        try drawer.drawRectangle(throttle_rectange, colors.Green, colors.Green);
    }

    pub fn iracing(self: *ComponentInput, data: iracing_sdk.SimulatorData) !void {
        self.clutch = try data.variables.clutch(data.values);
        self.brake = try data.variables.brake(data.values);
        self.throttle = try data.variables.throttle(data.values);
    }
};
