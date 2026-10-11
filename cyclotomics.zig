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

        var modulus = try cyclotomic_coeffs(allocator, order);
        defer modulus.deinit(allocator);
        reduce(new_coeffs.items, modulus.items);
        new_coeffs.shrinkRetainingCapacity(modulus.items.len - 1);

        self.coeffs.deinit(allocator);
        self.order = order;
        self.degree = phi(order);
        self.coeffs = new_coeffs;
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
        var modulus = try cyclotomic_coeffs(allocator, order);
        defer modulus.deinit(allocator);
        reduce(product.items, modulus.items);
        product.shrinkRetainingCapacity(modulus.items.len - 1);

        a.coeffs.deinit(allocator);
        a.coeffs = product;
        a.denom *= b.denom;
        a.canonicalize();
        return a;
    }
};

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
