const renderer = @import("render.zig");
const std = @import("std");

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

export fn test_canvas() void {
    const allocator = std.heap.page_allocator;
    var points: std.ArrayList(renderer.Point) = .empty;
    defer points.deinit(allocator);

    points.append(allocator, .{ .x = 100, .y = 200 }) catch unreachable;
    points.append(allocator, .{ .x = 200, .y = 200 }) catch unreachable;
    points.append(allocator, .{ .x = 200, .y = 100 }) catch unreachable;
    points.append(allocator, .{ .x = 150, .y = 150 }) catch unreachable;

    const cell: renderer.Cell = .{
        .mines = 0,
        .number = allocator.dupeZ(u8, "5") catch unreachable,
        .number_color = .{ .r = 100, .g = 100, .b = 100 },
        .shape = points,
        .neighbors = .empty,
        .linked = .empty,
    };
    renderer.render_cell(cell);
    renderer.render();
}
