const std = @import("std");
const nsweep = @import("nsweep.zig");

pub extern fn get_width() i32;
pub extern fn get_height() i32;

pub extern fn canvas_begin_path(id: u32) void;
pub extern fn canvas_line_to(id: u32, x: i32, y: i32) void;
pub extern fn canvas_move_to(id: u32, x: i32, y: i32) void;
pub extern fn canvas_fill(id: u32) void;
pub extern fn canvas_set_fill(id: u32, r: u8, g: u8, b: u8) void;
pub extern fn canvas_fill_text(id: u32, ptr: [*]const u8, len: usize, x: i32, y: i32) void;

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

    pub fn set_fill(self: Canvas, color: nsweep.Color) void {
        canvas_set_fill(self.id, color.r, color.g, color.b);
    }

    pub fn fill_text(self: Canvas, text: []const u8, x: i32, y: i32) void {
        canvas_fill_text(self.id, text.ptr, text.len, x, y);
    }
};

// my thought process for optimizing board rendering is to have a canvas for
// the base board and a canvas for hiding the board states, revealing cells can
// erase from the top canvas (or canvases depending on stroke details)
const background_canvas = Canvas.init(0);
const base_canvas = Canvas.init(1);
const mid_canvas = Canvas.init(2);
const upper_canvas = Canvas.init(3);

const Coordinates = struct {
    x: i32,
    y: i32,
};

pub const View = struct {
    x: f32,
    y: f32,
    zoom: f32,

    pub fn point_to_coordinates(self: View, point: nsweep.Point) Coordinates {
        return .{
            .x = @as(i32, @intFromFloat(self.zoom * point.x + self.x)),
            .y = @as(i32, @intFromFloat(self.zoom * point.y + self.y)),
        };
    }

    pub fn render_cell(self: View, cell: nsweep.Cell) void {
        const points = cell.shape;
        const last = points.items[points.items.len - 1];
        const last_c = self.point_to_coordinates(last);
        base_canvas.move_to(last_c.x, last_c.y);
        base_canvas.begin_path();
        for (points.items) |item| {
            const coordinates: Coordinates = self.point_to_coordinates(item);
            base_canvas.line_to(coordinates.x, coordinates.y);
        }
        base_canvas.set_fill(.{ .r = 227, .g = 216, .b = 167 });
        base_canvas.fill();
        mid_canvas.set_fill(cell.number_color);
        const center = get_cell_center(cell);
        const center_coordinates = self.point_to_coordinates(center);
        mid_canvas.fill_text(cell.number, center_coordinates.x, center_coordinates.y);
    }
};

fn get_cell_center(cell: nsweep.Cell) nsweep.Point {
    // simple weighted average of verts for now
    const points = cell.shape;
    var center: nsweep.Point = points.items[0];
    for (points.items) |point| {
        center = center.add(point);
    }
    return center.mul(1.0 / @as(f32, @floatFromInt(points.items.len)));
}
