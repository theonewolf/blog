// MIT License
//
// Copyright (c) 2021 - 2026 Wolfgang Richter
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

const std = @import("std");
const Aes256 = std.crypto.core.aes.Aes256;

/// Smallest even bit-width (2..128) that can represent 0..max-1.
pub fn evenBitWidth(max: u128) u8 {
    std.debug.assert(max >= 2);
    const bits: u8 = @intCast(128 - @clz(max - 1));
    return (bits + 1) & ~@as(u8, 1);
}

/// Pseudorandom function F(right, round) using AES-256, masked to `half` bits.
pub fn prf(aes: std.crypto.core.aes.AesEncryptCtx(Aes256), right: u128, half: u7, r: u8) u128 {
    var block: [16]u8 = @splat(0);
    std.mem.writeInt(u64, block[0..8], @truncate(right), .little);
    std.mem.writeInt(u64, block[8..16], r, .little);

    var out: [16]u8 = undefined;
    aes.encrypt(&out, &block);

    const mask = (@as(u128, 1) << half) - 1;
    return @as(u128, std.mem.readInt(u64, out[8..16], .little)) & mask;
}

/// Balanced Feistel network over a (2 * half)-bit block.
fn feistel(
    aes: std.crypto.core.aes.AesEncryptCtx(Aes256),
    x: u128,
    half: u7,
    rounds: u8,
    comptime inverse: bool,
) u128 {
    const mask = (@as(u128, 1) << half) - 1;
    var left = (x >> half) & mask;
    var right = x & mask;

    for (0..rounds) |i| {
        const r: u8 = if (inverse) rounds - 1 - @as(u8, @intCast(i)) else @intCast(i);
        if (inverse) {
            const prev_left = right ^ prf(aes, left, half, r);
            right = left;
            left = prev_left;
        } else {
            const next_right = left ^ prf(aes, right, half, r);
            left = right;
            right = next_right;
        }
    }

    return (left << half) | right;
}

/// Encrypts `x` in [0, max) into a pseudorandom permutation over [0, max).
pub fn encrypt(x: u128, max: u128, key: [32]u8, rounds: u8) u128 {
    std.debug.assert(x < max);
    const aes = Aes256.initEnc(key);
    const half: u7 = @intCast(evenBitWidth(max) / 2);

    var y = feistel(aes, x, half, rounds, false);
    while (y >= max) y = feistel(aes, y, half, rounds, false); // cycle walking
    return y;
}

/// Inverts `encrypt`, mapping any `y` in [0, max) back to its original `x`.
pub fn decrypt(y: u128, max: u128, key: [32]u8, rounds: u8) u128 {
    std.debug.assert(y < max);
    const aes = Aes256.initEnc(key);
    const half: u7 = @intCast(evenBitWidth(max) / 2);

    var x = feistel(aes, y, half, rounds, true);
    while (x >= max) x = feistel(aes, x, half, rounds, true); // cycle walking
    return x;
}

test "FFSEM is a bijection over [0, 1023)" {
    const max = 1023;
    const key: [32]u8 = @splat(0);
    var seen: [max]bool = @splat(false);

    for (0..max) |i| {
        const c = encrypt(i, max, key, 6);
        try std.testing.expect(c < max);
        try std.testing.expect(!seen[@intCast(c)]); // no collisions
        seen[@intCast(c)] = true;
        try std.testing.expectEqual(@as(u128, i), decrypt(c, max, key, 6));
    }
}

test "FFSEM works on a 128-bit domain" {
    const max: u128 = 1_000_000_000_000_000_000_000_000_000; // 10^27 (> 64 bits)
    const key: [32]u8 = @splat(0x42);
    const x: u128 = 123_456_789_012_345_678_901_234_567;
    const c = encrypt(x, max, key, 6);
    try std.testing.expect(c < max);
    try std.testing.expectEqual(x, decrypt(c, max, key, 6));
}
