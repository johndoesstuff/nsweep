const renderer = @import("render.zig");

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

export fn add_size() i32 {
    return renderer.get_width() + renderer.get_height();
}
