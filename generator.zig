const cyclotomic = @import("cyclotomics.zig");
const std = @import("std");

pub const Generator = struct {
    name: []const u8,
    rules: []const GeneratorRule,
};

// rules consist of a generated shape and an array of the shapes and transforms
// that can spawn from it
pub const GeneratorRule = struct {
    a: GeneratedShape,
    b: []const std.meta.Tuple(&.{ GeneratedShape, GeneratedTransform }),
};

// shape prototypes have names to identify them for tiling
pub const GeneratedShape = struct {
    name: []const u8,
    points: []const cyclotomic.CyclotomicPoint,
};

// implemented shapes are instances of shape prototypes that can populate a
// generated board, unlike generated shapes these carry their current transform
// to make populating future implemented shapes possible
pub const ImplementedShape = struct {
    name: []const u8,
    points: []const cyclotomic.CyclotomicPoint,
    transform: GeneratedTransform,
};

// all transforms are linear î, ĵ with offset
pub const GeneratedTransform = struct {
    ihat: cyclotomic.CyclotomicPoint,
    jhat: cyclotomic.CyclotomicPoint,
    offset: cyclotomic.CyclotomicPoint,
};

// a generated board stores an array of implemented shapes which can be
// iterated every generation step
pub const GeneratedBoard = std.ArrayList(ImplementedShape);

const Spawn = std.meta.Tuple(&.{ GeneratedShape, GeneratedTransform });
const CyclotomicPoint = cyclotomic.CyclotomicPoint;

// every implemented shape on the board spawns the children of its rule, a
// child that lands exactly on a shape already on the board is dropped
pub fn generate_step(allocator: std.mem.Allocator, generator: Generator, board: *GeneratedBoard) !void {
    var new_shapes = std.ArrayList(ImplementedShape).init(allocator);
    const parents = GeneratedBoard.*;
    for (parents.items) |parent| {
        // for each parent look for generator rule and spawn implemented
        // shapes with transforms
        var generator_rule = .empty;
        const parent_name = parent.name;
        for (generator.rules) |rule| {
            const rule_name = rule.a.name;
            if (std.mem.eql(u8, parent_name, rule_name)) {
                generator_rule = rule;
                break;
            }
        }
        if (generator_rule == .empty) {
            // unable to find rule for parent
            continue;
        }
        for (generator_rule.b) |spawn_tuple| {
            const shape = spawn_tuple[0];
            const transform = spawn_tuple[1];

            // TODO: merge spawn transform and parent transform
            const final_transform = transform;
            const implemented: ImplementedShape = .{
                .name = shape.name,
                .points = shape.points,
                .transform = final_transform,
            };

            const overlap = false;
            // TODO: check for overlaps

            if (!overlap) {
                try new_shapes.append(implemented);
            }
        }
    }
    try board.appendSlice(new_shapes.items);
}

pub fn grid(allocator: std.mem.Allocator) !Generator {
    const grid_square: GeneratedShape = .{
        .name = "grid-square",
        .points = try allocator.dupe(CyclotomicPoint, &.{
            try CyclotomicPoint.from_xy(allocator, 1, 1),
            try CyclotomicPoint.from_xy(allocator, -1, 1),
            try CyclotomicPoint.from_xy(allocator, -1, -1),
            try CyclotomicPoint.from_xy(allocator, 1, -1),
        }),
    };

    const rules = try allocator.dupe(GeneratorRule, &.{
        .{
            .a = grid_square,
            .b = try allocator.dupe(Spawn, &.{
                .{ grid_square, try translate(allocator, 0, 2) },
                .{ grid_square, try translate(allocator, 0, -2) },
                .{ grid_square, try translate(allocator, 2, 0) },
                .{ grid_square, try translate(allocator, -2, 0) },
            }),
        },
    });

    return .{ .name = "grid-generator", .rules = rules };
}

pub fn translate(allocator: std.mem.Allocator, x: i32, y: i32) !GeneratedTransform {
    const t: GeneratedTransform = .{
        CyclotomicPoint.from_xy(allocator, 0, 1),
        CyclotomicPoint.from_xy(allocator, 1, 0),
        CyclotomicPoint.from_xy(allocator, x, y),
    };
    return t;
}
