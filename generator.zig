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
