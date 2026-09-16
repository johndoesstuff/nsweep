const renderer = @import("render.zig");
const std = @import("std");

pub const Ruleset = struct {
    negative_mines: bool, // mines of negative value are possible
    multiple_mines: bool, // >1 mines per square are possible
    meta_numbering: bool, // number = sum of surrounding numbers
    upper_bounds: bool, // numbers like <n are possible
    lower_bounds: bool, // numbers like >n are possible
    not_bounds: bool, // numbers like !n are possible
    connected_cells: bool, // randomly linked cells
};

pub const Board = struct {
    cells: std.ArrayList(Cell),
    rules: Ruleset,
};

pub const Cell = struct {
    mines: i32, // signed for negative mines or multiple mines
    revealed: bool,
    number: []const u8, // string that prints for each cell
    number_color: Color,
    shape: std.ArrayList(Point),
    neighbors: std.ArrayList(*Cell), // used to calculate number
    linked: std.ArrayList(*Cell), // used for variants of interdependent cells
};

pub const Point = struct {
    x: f32,
    y: f32,
    pub fn add(self: Point, b: Point) Point {
        return .{
            .x = self.x + b.x,
            .y = self.y + b.y,
        };
    }
    pub fn mul(self: Point, c: f32) Point {
        return .{
            .x = self.x * c,
            .y = self.y * c,
        };
    }
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

export fn test_canvas() void {
    const allocator = std.heap.page_allocator;
    var points: std.ArrayList(Point) = .empty;
    defer points.deinit(allocator);

    points.append(allocator, .{ .x = 100, .y = 200 }) catch unreachable;
    points.append(allocator, .{ .x = 200, .y = 200 }) catch unreachable;
    points.append(allocator, .{ .x = 200, .y = 100 }) catch unreachable;
    points.append(allocator, .{ .x = 130, .y = 130 }) catch unreachable;

    const cell: Cell = .{
        .mines = 0,
        .number = allocator.dupeZ(u8, "5") catch unreachable,
        .number_color = .{ .r = 100, .g = 100, .b = 100 },
        .shape = points,
        .neighbors = .empty,
        .linked = .empty,
        .revealed = false,
    };

    var view: renderer.View = .{
        .x = 0.0,
        .y = 0.0,
        .zoom = 1.0,
    };
    view.render_cell(cell);
    renderer.render();
}
