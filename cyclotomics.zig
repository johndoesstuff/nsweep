const std = @import("std");
const expect = std.testing.expect;

pub const CyclotomicPoint = struct {
    order: u32, // degree = polynomial length needed to represent order, φ(x)
    degree: u32,
    denom: i32,
    coeffs: std.ArrayList(i32), // array of length degree

    pub fn deinit(self: *CyclotomicPoint, allocator: std.mem.Allocator) void {
        self.coeffs.deinit(allocator);
    }

    pub fn canonicalize(self: *CyclotomicPoint) void {
        // get divisor of denom and coeffs
        var divisor: u32 = @abs(self.denom);
        for (self.coeffs.items) |coeff| {
            divisor = std.math.gcd(divisor, @abs(coeff));
        }
        if (divisor > 1) {
            const signed_divisor: i32 = @intCast(divisor);
            self.denom = @divExact(self.denom, signed_divisor);
            for (self.coeffs.items, 0..) |_, i| {
                self.coeffs.items[i] = @divExact(self.coeffs.items[i], signed_divisor);
            }
        }
        if (self.denom < 0) {
            self.denom *= -1;
            for (self.coeffs.items, 0..) |_, i| {
                self.coeffs.items[i] *= -1;
            }
        }
    }

    pub fn promote(self: *CyclotomicPoint, allocator: std.mem.Allocator, order: u32) !void {
        if (self.order == order) {
            return;
        }

        // promoting order % current order must equal 0

        const stride = order / self.order;
        var new_coeffs: std.ArrayList(i32) = .empty;
        errdefer new_coeffs.deinit(allocator);

        // first we need to get an order-length coeff array before we can reduce to a degree-length one
        // the old coeff array is only degree-length so anything past it is 0

        for (0..order) |i| {
            if (i % stride == 0 and i / stride < self.coeffs.items.len) {
                try new_coeffs.append(allocator, self.coeffs.items[i / stride]);
            } else {
                try new_coeffs.append(allocator, 0);
            }
        }

        // now we reduce

        try reduce_by_order(allocator, &new_coeffs, order);

        self.coeffs.deinit(allocator);
        self.order = order;
        self.degree = phi(order);
        self.coeffs = new_coeffs;
    }

    // r * e^(2πi * k / n), the angle k/n of a turn with radius r
    pub fn from_angle(allocator: std.mem.Allocator, k: u32, n: u32, r: i32) !CyclotomicPoint {
        // lowest terms so the order stays as small as possible
        const g = std.math.gcd(k, n);
        const order = n / g;
        var coeffs: std.ArrayList(i32) = .empty;
        errdefer coeffs.deinit(allocator);
        try coeffs.appendNTimes(allocator, 0, order);
        coeffs.items[(k / g) % order] = r;
        try reduce_by_order(allocator, &coeffs, order);
        return .{ .order = order, .degree = phi(order), .denom = 1, .coeffs = coeffs };
    }

    // x + y * i as a point of order 4
    pub fn from_xy(allocator: std.mem.Allocator, x: i32, y: i32) !CyclotomicPoint {
        var coeffs: std.ArrayList(i32) = .empty;
        try coeffs.appendSlice(allocator, &.{ x, y });
        return .{ .order = 4, .degree = 2, .denom = 1, .coeffs = coeffs };
    }

    pub fn clone(self: CyclotomicPoint, allocator: std.mem.Allocator) !CyclotomicPoint {
        var copy = self;
        copy.coeffs = try self.coeffs.clone(allocator);
        return copy;
    }

    // self + other as a new point, both are promoted to a common order first
    pub fn add(self: CyclotomicPoint, allocator: std.mem.Allocator, other: CyclotomicPoint) !CyclotomicPoint {
        const order = std.math.lcm(self.order, other.order);
        var a = try self.clone(allocator);
        errdefer a.deinit(allocator);
        var b = try other.clone(allocator);
        defer b.deinit(allocator);
        try a.promote(allocator, order);
        try b.promote(allocator, order);

        // a/da + b/db = (a*db + b*da) / (da*db)
        for (a.coeffs.items, 0..) |_, i| {
            a.coeffs.items[i] = a.coeffs.items[i] * b.denom + b.coeffs.items[i] * a.denom;
        }
        a.denom *= b.denom;
        a.canonicalize();
        return a;
    }

    // self * other as a new point, both are promoted to a common order first
    pub fn mul(self: CyclotomicPoint, allocator: std.mem.Allocator, other: CyclotomicPoint) !CyclotomicPoint {
        const order = std.math.lcm(self.order, other.order);
        var a = try self.clone(allocator);
        errdefer a.deinit(allocator);
        var b = try other.clone(allocator);
        defer b.deinit(allocator);
        try a.promote(allocator, order);
        try b.promote(allocator, order);

        // multiply as polynomials in ζ, the product is up to 2 * degree long
        var product: std.ArrayList(i32) = .empty;
        errdefer product.deinit(allocator);
        try product.appendNTimes(allocator, 0, a.coeffs.items.len + b.coeffs.items.len);
        for (a.coeffs.items, 0..) |x, i| {
            for (b.coeffs.items, 0..) |y, j| {
                product.items[i + j] += x * y;
            }
        }

        // then reduce back down to degree length
        try reduce_by_order(allocator, &product, order);

        a.coeffs.deinit(allocator);
        a.coeffs = product;
        a.denom *= b.denom;
        a.canonicalize();
        return a;
    }

    // self - other as a new point
    pub fn sub(self: CyclotomicPoint, allocator: std.mem.Allocator, other: CyclotomicPoint) !CyclotomicPoint {
        var negated = try other.clone(allocator);
        defer negated.deinit(allocator);
        for (negated.coeffs.items, 0..) |_, i| {
            negated.coeffs.items[i] *= -1;
        }
        return self.add(allocator, negated);
    }

    // equal when the difference is 0, points of the same order are in a
    // unique canonical form so they compare coeff for coeff, mixed orders
    // subtract out of a stack buffer so no heap allocation is needed
    pub fn eql(self: CyclotomicPoint, allocator: std.mem.Allocator, other: CyclotomicPoint) !bool {
        if (self.order == other.order) {
            return self.denom == other.denom and std.mem.eql(i32, self.coeffs.items, other.coeffs.items);
        }
        var stack = std.heap.stackFallback(2048, allocator);
        const scratch = stack.get();
        var difference = try self.sub(scratch, other);
        defer difference.deinit(scratch);
        for (difference.coeffs.items) |c| {
            if (c != 0) {
                return false;
            }
        }
        return true;
    }

    // evaluate at ζ = e^(2πi / order) to get plain floating point x, y
    pub fn to_xy(self: CyclotomicPoint) Xy {
        var x: f64 = 0;
        var y: f64 = 0;
        const order: f64 = @floatFromInt(self.order);
        for (self.coeffs.items, 0..) |c, k| {
            const angle = 2.0 * std.math.pi * @as(f64, @floatFromInt(k)) / order;
            const coeff: f64 = @floatFromInt(c);
            x += coeff * @cos(angle);
            y += coeff * @sin(angle);
        }
        const denom: f64 = @floatFromInt(self.denom);
        return .{ .x = x / denom, .y = y / denom };
    }
};

pub const Xy = struct {
    x: f64,
    y: f64,
};

// reduce a polynomial in ζ_order down to degree length
pub fn reduce_by_order(allocator: std.mem.Allocator, poly: *std.ArrayList(i32), order: u32) !void {
    var modulus = try cyclotomic_coeffs(allocator, order);
    defer modulus.deinit(allocator);
    reduce(poly.items, modulus.items);
    poly.shrinkRetainingCapacity(modulus.items.len - 1);
}

// reduce a polynomial in place modulo a monic polynomial, the top coeffs end up 0
pub fn reduce(coeffs: []i32, modulus: []const i32) void {
    const degree = modulus.len - 1;
    var i = coeffs.len;
    while (i > degree) {
        i -= 1;
        const top = coeffs[i];
        // subtract top * x^(i - degree) * modulus to kill the x^i term
        for (modulus, 0..) |m, j| {
            coeffs[i - degree + j] -= top * m;
        }
    }
}

// multiply a polynomial by (x^d - 1) in place
fn multiply_by_binomial(allocator: std.mem.Allocator, poly: *std.ArrayList(i32), d: usize) !void {
    const old_len = poly.items.len;
    try poly.appendNTimes(allocator, 0, d);
    // go from the top down so each old coeff is read before it gets overwritten
    var i = old_len;
    while (i > 0) {
        i -= 1;
        const old = poly.items[i];
        poly.items[i + d] += old;
        poly.items[i] = -old;
    }
}

// divide a polynomial by (x^d - 1) in place, assumes the division is exact
fn divide_by_binomial(poly: *std.ArrayList(i32), d: usize) void {
    // if p = q * (x^d - 1) then p[j] = q[j - d] - q[j], so q[j] = q[j - d] - p[j]
    for (poly.items, 0..) |_, j| {
        var above: i32 = 0;
        if (j >= d) {
            above = poly.items[j - d];
        }
        poly.items[j] = above - poly.items[j];
    }
    poly.shrinkRetainingCapacity(poly.items.len - d);
}

// get coeff array from order
// Φ_n(x) = product over d | n of (x^d - 1)^μ(n/d)
pub fn cyclotomic_coeffs(allocator: std.mem.Allocator, order: u32) !std.ArrayList(i32) {
    var result: std.ArrayList(i32) = .empty;
    errdefer result.deinit(allocator);
    try result.append(allocator, 1);

    // do all the multiplications first so every division along the way is exact

    for (1..order + 1) |d| {
        if (order % d == 0) {
            if (mobuis(order / @as(u32, @intCast(d))) == 1) {
                try multiply_by_binomial(allocator, &result, d);
            }
        }
    }

    for (1..order + 1) |d| {
        if (order % d == 0) {
            if (mobuis(order / @as(u32, @intCast(d))) == -1) {
                divide_by_binomial(&result, d);
            }
        }
    }

    return result;
}

// mobuis function
pub fn mobuis(n: u32) i32 {
    if (n == 1) {
        return 1;
    }
    var remaining = n;
    var result: i32 = 1;
    var p: u32 = 2;
    while (p * p <= remaining) : (p += 1) {
        if (remaining % p == 0) {
            remaining /= p;
            if (remaining % p == 0) {
                // squared prime factor
                return 0;
            }
            result *= -1;
        }
    }
    if (remaining > 1) {
        // whatever is left is one more prime
        result *= -1;
    }
    return result;
}

// eulers totient
pub fn phi(n: u32) u32 {
    var count: u32 = 0;
    for (1..n + 1) |i| {
        if (std.math.gcd(i, n) == 1) {
            count += 1;
        }
    }
    return count;
}

test "Eulers Totient" {
    try expect(phi(1) == 1);
    try expect(phi(9) == 6);
    try expect(phi(12) == 4);
}

test "Mobius" {
    try expect(mobuis(1) == 1);
    try expect(mobuis(2) == -1);
    try expect(mobuis(4) == 0);
    try expect(mobuis(6) == 1);
    try expect(mobuis(30) == -1);
}
