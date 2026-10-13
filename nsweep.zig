const renderer = @import("render.zig");
const cyclotomic = @import("cyclotomics.zig");
const generator = @import("generator.zig");
const std = @import("std");

pub const Ruleset = struct {
    negative_mines: bool, // mines of negative value are possible
    multiple_mines: bool, // >1 mines per square are possible
    meta_numbering: bool, // number = sum of surrounding numbers
    upper_bounds: bool, // numbers like <n are possible
    lower_bounds: bool, // numbers like >n are possible
    not_bounds: bool, // numbers like !n are possible
    connected_cells: bool, // randomly linked cells
    mine_density: f32, // how likely a mine is to spawn between [0, 1]
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

// turn a generated board into an actual board, two cells are neighbors when
// their shapes share a point. neighbor pointers point into the returned list
// so it must not grow afterwards
pub fn crystalize_generated(allocator: std.mem.Allocator, board: generator.GeneratedBoard) !std.ArrayList(Cell) {
    // exact transformed points of every shape, kept for the neighbor check
    var exact: std.ArrayList(std.ArrayList(cyclotomic.CyclotomicPoint)) = .empty;
    defer {
        for (exact.items) |*points| {
            for (points.items) |*point| point.deinit(allocator);
            points.deinit(allocator);
        }
        exact.deinit(allocator);
    }

    var cells: std.ArrayList(Cell) = .empty;
    errdefer cells.deinit(allocator);
    for (board.items) |shape| {
        var points: std.ArrayList(cyclotomic.CyclotomicPoint) = .empty;
        var outline: std.ArrayList(Point) = .empty;
        for (shape.points) |point| {
            // transforms apply as ihat * point + offset, same as merge_transform
            var scaled = try shape.transform.ihat.mul(allocator, point);
            defer scaled.deinit(allocator);
            const moved = try scaled.add(allocator, shape.transform.offset);
            try points.append(allocator, moved);
            const xy = moved.to_xy();
            try outline.append(allocator, .{ .x = @floatCast(xy.x), .y = @floatCast(xy.y) });
        }
        try exact.append(allocator, points);
        try cells.append(allocator, .{
            .mines = 0,
            .revealed = false,
            .number = "",
            .number_color = .{ .r = 0, .g = 0, .b = 0 },
            .shape = outline,
            .neighbors = .empty,
            .linked = .empty,
        });
    }

    for (cells.items, 0..) |*a, i| {
        for (cells.items[i + 1 ..], i + 1..) |*b, j| {
            if (try share_point(allocator, exact.items[i].items, exact.items[j].items)) {
                try a.neighbors.append(allocator, b);
                try b.neighbors.append(allocator, a);
            }
        }
    }
    return cells;
}

fn share_point(allocator: std.mem.Allocator, a: []const cyclotomic.CyclotomicPoint, b: []const cyclotomic.CyclotomicPoint) !bool {
    for (a) |point_a| {
        for (b) |point_b| {
            if (try point_a.eql(allocator, point_b)) return true;
        }
    }
    return false;
}

// casts a ray to the right and counts crossings of the shapes edges, odd count
// means the point is inside
pub fn point_in_cell(point: Point, cell: Cell) bool {
    const points = cell.shape.items;
    var inside = false;
    var j = points.len - 1;
    for (points, 0..) |a, i| {
        const b = points[j];
        if ((a.y > point.y) != (b.y > point.y)) {
            const cross_x = (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x;
            if (point.x < cross_x) inside = !inside;
        }
        j = i;
    }
    return inside;
}

var current_board: ?Board = null;
var mouse_x: i32 = 0;
var mouse_y: i32 = 0;

export fn render_board() void {
    renderer.clear_all();
    var view: renderer.View = .{
        .x = @floatFromInt(@divTrunc(renderer.get_width(), 2)),
        .y = @floatFromInt(@divTrunc(renderer.get_height(), 2)),
        .zoom = 20.0,
    };
    if (current_board) |board| {
        const mouse = view.coordinates_to_point(.{ .x = mouse_x, .y = mouse_y });
        for (board.cells.items) |c| {
            view.render_cell(c, point_in_cell(mouse, c));
        }
    }
    renderer.render();
}

export fn initialize_board(rng_seed: u32) void {
    const allocator = std.heap.page_allocator;
    var points: std.ArrayList(Point) = .empty;
    defer points.deinit(allocator);

    const grid_generator = generator.snub_square(allocator) catch unreachable;
    var generated_board: generator.GeneratedBoard = .empty;
    const seed = grid_generator.rules[0].a;
    generated_board.append(allocator, generator.implement(allocator, seed, generator.translate(allocator, 0, 0) catch unreachable) catch unreachable) catch unreachable;

    for (0..8) |_| {
        generator.generate_step(allocator, grid_generator, &generated_board) catch unreachable;
    }
    const cells = crystalize_generated(allocator, generated_board) catch unreachable;
    current_board = .{
        .cells = cells,
        .rules = .{
            .negative_mines = false,
            .multiple_mines = false,
            .meta_numbering = false,
            .upper_bounds = false,
            .lower_bounds = false,
            .not_bounds = false,
            .connected_cells = false,
            .mine_density = 0.15,
        },
    };
    generate_mines(&current_board.?, rng_seed);
}

fn generate_mines(board: *Board, seed: u32) void {
    var prng = std.Random.DefaultPrng.init(seed);
    const density = board.rules.mine_density;
    for (board.cells.items) |*cell| {
        if (prng.random().float(f32) < density) {
            cell.mines = 1;
        }
    }
    for (board.cells.items) |*cell| {
        var neighbor_mines: i32 = 0;
        for (cell.neighbors.items) |neighbor| {
            neighbor_mines += neighbor.mines;
        }
        cell.number = std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{neighbor_mines}) catch unreachable;
    }
}

export fn update_mouse(x: i32, y: i32) void {
    mouse_x = x;
    mouse_y = y;
}
