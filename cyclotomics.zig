const std = @import("std");
const expect = std.testing.expect;

pub const CyclotomicPoint = struct {
    order: u32, // degree = polynomial length needed to represent order, Φ(x)
    degree: u32,
    denom: i32,
    coeffs: std.ArrayList(i32),
    pub fn canonicalize(self: CyclotomicPoint) CyclotomicPoint {
        // get divisor of denom and coeffs
        var divisor: u32 = self.denom;
        for (self.coeffs.items) |coeff| {
            divisor = std.math.gcd(divisor, coeff);
        }
        if (divisor > 1) {
            self.denom /= divisor;
            for (self.coeffs.items, 0..) |_, i| {
                self.coeffs.items[i] /= divisor;
            }
        }
        if (self.denom < 0) {
            self.denom *= -1;
            for (self.coeffs.items, 0..) |_, i| {
                self.coeffs.items[i] *= -1;
            }
        }
        return self;
    }

    pub fn promote(self: CyclotomicPoint, order: u32) CyclotomicPoint {
        if (self.order == order) {
            return self;
        }

        // promoting order % current order must equal 0

        const stride = order / self.order;
        const allocator = std.heap.page_allocator;
        var new_coeffs: std.ArrayList(i32) = .empty;
        for (0..order) |i| {
            if (i % stride == 0) {
                new_coeffs.append(allocator, self.coeffs.items[i / stride]) catch unreachable;
            } else {
                new_coeffs.append(allocator, 0) catch unreachable;
            }
        }
        self.coeffs = new_coeffs;
        return self;
    }
};

// eulers totient
pub fn phi(n: u32) u32 {
    var count = 0;
    for (1..n) |i| {
        if (std.math.gcd(i, n) == 1) {
            count += 1;
        }
    }
    return count;
}

test "Eulers Totient" {
    try expect(phi(9) == 6);
}
