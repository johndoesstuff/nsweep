pub extern fn get_width() i32;
pub extern fn get_height() i32;

pub extern fn canvas_begin_path(id: u32) void;
pub extern fn canvas_line_to(x: i32, y: i32, id: u32) void;
pub extern fn canvas_move_to(x: i32, y: i32, id: u32) void;
pub extern fn canvas_fill(id: u32) void;

pub const Canvas = struct {
    id: u32,

    pub fn init(id: u32) Canvas {
        return .{ .id = id };
    }

    pub fn begin_path(self: Canvas) void {
        canvas_begin_path(self.id);
    }

    pub fn line_to(self: Canvas, x: i32, y: i32) void {
        line_to(self.id, x, y);
    }

    pub fn move_to(self: Canvas, x: i32, y: i32) void {
        line_to(self.id, x, y);
    }

    pub fn fill(self: Canvas) void {
        canvas_fill(self.id);
    }
};

pub const background_canvas = Canvas.init(0);
pub const base_canvas = Canvas.init(1);
pub const upper_canvas = Canvas.init(2);

const Point = struct {
    x: f32,
    y: f32,
};

// my thought process for optimizing board rendering is to have a canvas for
// the base board and a canvas for hiding the board states, revealing cells can
// erase from the top canvas (or canvases depending on stroke details)

fn render_cell() void {}
