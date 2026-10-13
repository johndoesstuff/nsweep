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

    pub fn eql(self: GeneratedTransform, allocator: std.mem.Allocator, other: GeneratedTransform) !bool {
        return try self.ihat.eql(allocator, other.ihat) and try self.jhat.eql(allocator, other.jhat) and try self.offset.eql(allocator, other.offset);
    }
};

// a generated board stores an array of implemented shapes which can be
// iterated every generation step
pub const GeneratedBoard = std.ArrayList(ImplementedShape);

const Spawn = std.meta.Tuple(&.{ GeneratedShape, GeneratedTransform });
const CyclotomicPoint = cyclotomic.CyclotomicPoint;

// every implemented shape on the board spawns the children of its rule, a
// child that lands exactly on a shape already on the board is dropped
pub fn generate_step(allocator: std.mem.Allocator, generator: Generator, board: *GeneratedBoard) !void {
    var new_shapes: std.ArrayList(ImplementedShape) = .empty;
    defer new_shapes.deinit(allocator);
    const parents = board.*;
    for (parents.items) |parent| {
        // for each parent look for generator rule and spawn implemented
        // shapes with transforms
        var generator_rule: ?GeneratorRule = null;
        const parent_name = parent.name;
        for (generator.rules) |rule| {
            const rule_name = rule.a.name;
            if (std.mem.eql(u8, parent_name, rule_name)) {
                generator_rule = rule;
                break;
            }
        }
        // unable to find rule for parent
        const found_rule = generator_rule orelse continue;
        for (found_rule.b) |spawn_tuple| {
            const shape = spawn_tuple[0];
            const transform = spawn_tuple[1];

            const final_transform = try merge_transform(allocator, transform, parent.transform);
            const implemented: ImplementedShape = .{
                .name = shape.name,
                .points = shape.points,
                .transform = final_transform,
            };

            var overlap = false;
            for (parents.items) |potential_overlap| {
                if (std.mem.eql(u8, potential_overlap.name, implemented.name)) {
                    if (try implemented.transform.eql(allocator, potential_overlap.transform)) {
                        overlap = true;
                        break;
                    }
                }
            }

            for (new_shapes.items) |potential_overlap| {
                if (std.mem.eql(u8, potential_overlap.name, implemented.name)) {
                    if (try implemented.transform.eql(allocator, potential_overlap.transform)) {
                        overlap = true;
                        break;
                    }
                }
                if (overlap) break;
            }

            if (!overlap) {
                try new_shapes.append(allocator, implemented);
            }
        }
    }
    try board.appendSlice(allocator, new_shapes.items);
}

// merging applies b first then a
pub fn merge_transform(allocator: std.mem.Allocator, a: GeneratedTransform, b: GeneratedTransform) !GeneratedTransform {
    var offset = try a.ihat.mul(allocator, b.offset);
    defer offset.deinit(allocator);
    return .{
        .ihat = try a.ihat.mul(allocator, b.ihat),
        .jhat = try a.ihat.mul(allocator, b.jhat),
        .offset = try offset.add(allocator, a.offset),
    };
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
    return .{
        .ihat = try CyclotomicPoint.from_xy(allocator, 1, 0),
        .jhat = try CyclotomicPoint.from_xy(allocator, 0, 1),
        .offset = try CyclotomicPoint.from_xy(allocator, x, y),
    };
}
