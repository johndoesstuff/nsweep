const std = @import("std");

pub extern fn get_width() i32;
pub extern fn get_height() i32;

pub extern fn canvas_begin_path(id: u32) void;
pub extern fn canvas_line_to(id: u32, x: i32, y: i32) void;
pub extern fn canvas_move_to(id: u32, x: i32, y: i32) void;
pub extern fn canvas_fill(id: u32) void;
pub extern fn canvas_set_fill(id: u32, r: u8, g: u8, b: u8) void;

pub extern fn render() void;

pub const Canvas = struct {
    id: u32,

    pub fn init(id: u32) Canvas {
        return .{ .id = id };
    }

    pub fn begin_path(self: Canvas) void {
        canvas_begin_path(self.id);
    }

    pub fn line_to(self: Canvas, x: i32, y: i32) void {
        canvas_line_to(self.id, x, y);
    }

    pub fn move_to(self: Canvas, x: i32, y: i32) void {
        canvas_move_to(self.id, x, y);
    }

    pub fn fill(self: Canvas) void {
        canvas_fill(self.id);
    }

    pub fn set_fill(self: Canvas, r: u8, g: u8, b: u8) void {
        canvas_set_fill(self.id, r, g, b);
    }
};

const background_canvas = Canvas.init(0);
const base_canvas = Canvas.init(1);
const upper_canvas = Canvas.init(2);

pub const Point = struct {
    x: i32,
    y: i32,
};

// my thought process for optimizing board rendering is to have a canvas for
// the base board and a canvas for hiding the board states, revealing cells can
// erase from the top canvas (or canvases depending on stroke details)

pub fn render_cell(points: std.ArrayList(Point)) void {
    const last = points.items[points.items.len - 1];
    base_canvas.move_to(last.x, last.y);
    base_canvas.begin_path();
    for (points.items) |item| {
        base_canvas.line_to(item.x, item.y);
    }
    base_canvas.set_fill(227, 216, 167);
    base_canvas.fill();
}
