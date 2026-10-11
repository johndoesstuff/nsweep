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

// all transforms are linear î, ĵ with offset
pub const GeneratedTransform = struct {
    ihat: cyclotomic.CyclotomicPoint,
    jhat: cyclotomic.CyclotomicPoint,
    offset: cyclotomic.CyclotomicPoint,
};

const allocator = std.heap.page_allocator;
const grid_square: GeneratedShape = .{
    "grid-square",
    .{
        cyclotomic.from_xy(allocator, 1, 1),
        cyclotomic.from_xy(allocator, 1, -1),
        cyclotomic.from_xy(allocator, -1, 1),
        cyclotomic.from_xy(allocator, -1, -1),
    },
};

pub const grid: Generator = .{
    "grid-generator",
    .{
        .{
            grid_square,
            .{
                .{
                    grid_square,
                    .{
                        cyclotomic.from_xy(allocator, 0, 1),
                        cyclotomic.from_xy(allocator, 1, 0),
                        cyclotomic.from_xy(allocator, 0, 1),
                    },
                },
                .{
                    grid_square,
                    .{
                        cyclotomic.from_xy(allocator, 0, 1),
                        cyclotomic.from_xy(allocator, 1, 0),
                        cyclotomic.from_xy(allocator, 0, -1),
                    },
                },
                .{
                    grid_square,
                    .{
                        cyclotomic.from_xy(allocator, 0, 1),
                        cyclotomic.from_xy(allocator, 1, 0),
                        cyclotomic.from_xy(allocator, 1, 0),
                    },
                },
                .{
                    grid_square,
                    .{
                        cyclotomic.from_xy(allocator, 0, 1),
                        cyclotomic.from_xy(allocator, 1, 0),
                        cyclotomic.from_xy(allocator, -1, 0),
                    },
                },
            },
        },
    },
};
