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
    b: []const @Tuple(&.{ GeneratedShape, GeneratedTransform }),
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
    // sum of the transformed points, used to spot shapes landing on the same
    // spot even when rotated differently
    center: cyclotomic.CyclotomicPoint,
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

const Spawn = @Tuple(&.{ GeneratedShape, GeneratedTransform });
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

            // the spawn transform is in the parent's frame so the parent is applied last
            const final_transform = try merge_transform(allocator, parent.transform, transform);
            const implemented = try implement(allocator, shape, final_transform);

            var overlap = false;
            for (parents.items) |potential_overlap| {
                if (std.mem.eql(u8, potential_overlap.name, implemented.name)) {
                    if (try implemented.center.eql(allocator, potential_overlap.center)) {
                        overlap = true;
                        break;
                    }
                }
            }

            for (new_shapes.items) |potential_overlap| {
                if (std.mem.eql(u8, potential_overlap.name, implemented.name)) {
                    if (try implemented.center.eql(allocator, potential_overlap.center)) {
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

// instance a shape prototype with a transform
pub fn implement(allocator: std.mem.Allocator, shape: GeneratedShape, transform: GeneratedTransform) !ImplementedShape {
    var center = try transform.offset.mul(allocator, try CyclotomicPoint.from_xy(allocator, @intCast(shape.points.len), 0));
    for (shape.points) |p| {
        const scaled = try transform.ihat.mul(allocator, p);
        center = try center.add(allocator, scaled);
    }
    return .{ .name = shape.name, .points = shape.points, .transform = transform, .center = center };
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

// 3.3.4.3.4 (snub square), squares in two orientations a twelfth of a turn
// apart with a triangle on every square edge, the two square orientations
// are mirror images in how their triangles attach so they need separate
// rules even though they are the same shape, every triangle has square a on
// its first edge, another triangle on its second and square b on its third
pub fn snub_square(allocator: std.mem.Allocator) !Generator {
    const square_points = try allocator.dupe(CyclotomicPoint, &.{
        try CyclotomicPoint.from_xy(allocator, 0, 0),
        try CyclotomicPoint.from_xy(allocator, 2, 0),
        try CyclotomicPoint.from_xy(allocator, 2, 2),
        try CyclotomicPoint.from_xy(allocator, 0, 2),
    });
    const square_a: GeneratedShape = .{ .name = "snub-square-a", .points = square_points };
    const square_b: GeneratedShape = .{ .name = "snub-square-b", .points = square_points };
    const tri: GeneratedShape = .{
        .name = "snub-triangle",
        .points = try allocator.dupe(CyclotomicPoint, &.{
            try CyclotomicPoint.from_xy(allocator, 0, 0),
            try CyclotomicPoint.from_xy(allocator, 2, 0),
            try CyclotomicPoint.from_angle(allocator, 1, 6, 2),
        }),
    };
    // the triangle across the second edge sits at 2 + 2ζ6
    const across = try (try CyclotomicPoint.from_xy(allocator, 2, 0)).add(allocator, try CyclotomicPoint.from_angle(allocator, 1, 6, 2));

    const rules = try allocator.dupe(GeneratorRule, &.{
        .{
            .a = square_a,
            .b = try allocator.dupe(Spawn, &.{
                .{ tri, try rotate(allocator, 6, 12, try CyclotomicPoint.from_xy(allocator, 2, 0)) },
                .{ tri, try rotate(allocator, 9, 12, try CyclotomicPoint.from_xy(allocator, 2, 2)) },
                .{ tri, try rotate(allocator, 0, 12, try CyclotomicPoint.from_xy(allocator, 0, 2)) },
                .{ tri, try rotate(allocator, 3, 12, try CyclotomicPoint.from_xy(allocator, 0, 0)) },
            }),
        },
        .{
            .a = square_b,
            .b = try allocator.dupe(Spawn, &.{
                .{ tri, try rotate(allocator, 10, 12, try CyclotomicPoint.from_xy(allocator, 0, 0)) },
                .{ tri, try rotate(allocator, 1, 12, try CyclotomicPoint.from_xy(allocator, 2, 0)) },
                .{ tri, try rotate(allocator, 4, 12, try CyclotomicPoint.from_xy(allocator, 2, 2)) },
                .{ tri, try rotate(allocator, 7, 12, try CyclotomicPoint.from_xy(allocator, 0, 2)) },
            }),
        },
        .{
            .a = tri,
            .b = try allocator.dupe(Spawn, &.{
                .{ square_a, try rotate(allocator, 3, 12, try CyclotomicPoint.from_xy(allocator, 2, -2)) },
                .{ tri, try rotate(allocator, 6, 12, across) },
                .{ square_b, try rotate(allocator, 2, 12, try CyclotomicPoint.from_xy(allocator, 0, 0)) },
            }),
        },
    });

    return .{ .name = "snub-square-generator", .rules = rules };
}

// turn by k/n of a full turn then move by offset
pub fn rotate(allocator: std.mem.Allocator, k: u32, n: u32, offset: CyclotomicPoint) !GeneratedTransform {
    const ihat = try CyclotomicPoint.from_angle(allocator, k, n, 1);
    return .{
        .ihat = ihat,
        .jhat = try ihat.mul(allocator, try CyclotomicPoint.from_xy(allocator, 0, 1)),
        .offset = offset,
    };
}
