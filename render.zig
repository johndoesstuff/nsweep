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
pub extern fn canvas_clear_rect(id: u32, x0: i32, y0: i32, x1: i32, y1: i32) void;
pub extern fn clear_all() void;
pub extern fn canvas_text_align_center(id: u32) void;
pub extern fn canvas_text_baseline_middle(id: u32) void;

pub extern fn render() void;

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const number_colors: [12]Color = .{
    .{ .r = 0, .b = 0, .g = 0 }, // 0
    .{ .r = 27, .b = 67, .g = 133 }, // 1
    .{ .r = 44, .b = 135, .g = 28 }, // 2
    .{ .r = 156, .b = 33, .g = 33 }, // 3
    .{ .r = 32, .b = 21, .g = 117 }, // 4
    .{ .r = 102, .b = 34, .g = 21 }, // 5
    .{ .r = 24, .b = 110, .g = 115 }, // 6
    .{ .r = 28, .b = 28, .g = 28 }, // 7
    .{ .r = 87, .b = 87, .g = 87 }, // 8
    .{ .r = 133, .b = 46, .g = 130 }, // 9
    .{ .r = 115, .b = 107, .g = 1 }, // 10
    .{ .r = 0, .b = 0, .g = 0 }, // 11+
};

pub const mine_color: Color = .{ .r = 28, .b = 28, .g = 28 };
pub const board_color: Color = .{ .r = 227, .g = 216, .b = 167 };
pub const board_hover_color: Color = .{ .r = 247, .g = 236, .b = 187 };

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

    pub fn set_fill(self: Canvas, color: Color) void {
        canvas_set_fill(self.id, color.r, color.g, color.b);
    }

    pub fn fill_text(self: Canvas, text: []const u8, x: i32, y: i32) void {
        canvas_fill_text(self.id, text.ptr, text.len, x, y);
    }

    pub fn clear_rect(self: Canvas, x0: i32, y0: i32, x1: i32, y1: i32) void {
        canvas_clear_rect(self.id, x0, y0, x1, y1);
    }

    pub fn text_align_center(self: Canvas) void {
        canvas_text_align_center(self.id);
    }

    pub fn text_baseline_middle(self: Canvas) void {
        canvas_text_baseline_middle(self.id);
    }
};

// my thought process for optimizing board rendering is to have a canvas for
// the base board and a canvas for hiding the board states, revealing cells can
// erase from the top canvas (or canvases depending on stroke details)
const background_canvas = Canvas.init(0);
const base_canvas = Canvas.init(1);
const mid_canvas = Canvas.init(2);
const upper_canvas = Canvas.init(3);

pub const Coordinates = struct {
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

    pub fn coordinates_to_point(self: View, coordinates: Coordinates) nsweep.Point {
        return .{
            .x = (@as(f32, @floatFromInt(coordinates.x)) - self.x) / self.zoom,
            .y = (@as(f32, @floatFromInt(coordinates.y)) - self.y) / self.zoom,
        };
    }

    pub fn render_cell(self: View, cell: nsweep.Cell, hover: bool) void {
        const points = cell.shape;
        const last = points.items[points.items.len - 1];
        const last_c = self.point_to_coordinates(last);
        const center = get_cell_center(cell);
        const center_coordinates = self.point_to_coordinates(center);

        base_canvas.move_to(last_c.x, last_c.y);
        base_canvas.begin_path();
        for (points.items) |item| {
            const coordinates: Coordinates = self.point_to_coordinates(item);
            base_canvas.line_to(coordinates.x, coordinates.y);
        }

        if (hover) {
            base_canvas.set_fill(board_hover_color);
        } else {
            base_canvas.set_fill(board_color);
        }
        base_canvas.fill();

        if (cell.mines == 0) {
            mid_canvas.set_fill(cell.number_color);
            mid_canvas.text_align_center();
            mid_canvas.text_baseline_middle();
            mid_canvas.fill_text(cell.number, center_coordinates.x, center_coordinates.y);
        } else {
            mid_canvas.begin_path();
            for (points.items) |item| {
                const coordinates = self.point_to_coordinates(center.add(item.add(center.mul(-1)).mul(0.5)));
                mid_canvas.line_to(coordinates.x, coordinates.y);
            }
            mid_canvas.set_fill(mine_color);
            mid_canvas.fill();
        }
    }
};

fn get_cell_center(cell: nsweep.Cell) nsweep.Point {
    // simple weighted average of verts for now
    const points = cell.shape;
    var center: nsweep.Point = .{ .x = 0.0, .y = 0.0 };
    for (points.items) |point| {
        center = center.add(point);
    }
    return center.mul(1.0 / @as(f32, @floatFromInt(points.items.len)));
}
