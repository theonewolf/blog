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
const ffsem = @import("ffsem.zig");
const Aes256 = std.crypto.core.aes.Aes256;

const MAX_TRACE_STEPS = 256;
const STEP_STRIDE = 10; // [walk, round, left_lo, left_hi, right_lo, right_hi, f_lo, f_hi, state_lo, state_hi]

var key_buf: [32]u8 = @splat(0);
// [0..2]: x (lo, hi), [2..4]: max (lo, hi), [4..6]: out (lo, hi),
// [6]: width, [7]: half, [8]: num_steps, [9]: num_walks
var io_buf: [10]u64 = @splat(0);
var trace_buf: [MAX_TRACE_STEPS * STEP_STRIDE]u64 = @splat(0);

pub export fn keyPtr() [*]u8 {
    return &key_buf;
}

pub export fn ioPtr() [*]u64 {
    return &io_buf;
}

pub export fn tracePtr() [*]u64 {
    return &trace_buf;
}

fn readU128(lo: u64, hi: u64) u128 {
    return (@as(u128, hi) << 64) | @as(u128, lo);
}

fn writeU128(dst: *[2]u64, v: u128) void {
    dst[0] = @truncate(v);
    dst[1] = @truncate(v >> 64);
}

fn run(rounds: u8, comptime inverse: bool) u32 {
    const x = readU128(io_buf[0], io_buf[1]);
    const max = readU128(io_buf[2], io_buf[3]);
    if (max < 2) return 1;
    if (x >= max) return 2;
    if (rounds == 0 or rounds > 32) return 3;

    const aes = Aes256.initEnc(key_buf);
    const width = ffsem.evenBitWidth(max);
    const half: u7 = @intCast(width / 2);
    const mask = (@as(u128, 1) << half) - 1;

    var val = x;
    var walk: u64 = 0;
    var step_idx: usize = 0;

    while (true) {
        var left = (val >> half) & mask;
        var right = val & mask;

        for (0..rounds) |i| {
            const r: u8 = if (inverse) rounds - 1 - @as(u8, @intCast(i)) else @intCast(i);
            const f = if (inverse) ffsem.prf(aes, left, half, r) else ffsem.prf(aes, right, half, r);
            const next_left = if (inverse) right ^ f else right;
            const next_right = if (inverse) left else left ^ f;
            const state = (next_left << half) | next_right;

            if (step_idx < MAX_TRACE_STEPS) {
                const base = step_idx * STEP_STRIDE;
                trace_buf[base + 0] = walk;
                trace_buf[base + 1] = r;
                writeU128(trace_buf[base + 2 ..][0..2], left);
                writeU128(trace_buf[base + 4 ..][0..2], right);
                writeU128(trace_buf[base + 6 ..][0..2], f);
                writeU128(trace_buf[base + 8 ..][0..2], state);
                step_idx += 1;
            }

            left = next_left;
            right = next_right;
        }

        val = (left << half) | right;
        walk += 1;
        if (val < max) break;
    }

    writeU128(io_buf[4..6], val);
    io_buf[6] = width;
    io_buf[7] = half;
    io_buf[8] = step_idx;
    io_buf[9] = walk;
    return 0;
}

pub export fn runEncrypt(rounds: u8) u32 {
    return run(rounds, false);
}

pub export fn runDecrypt(rounds: u8) u32 {
    return run(rounds, true);
}

test "wasm wrapper matches ffsem encrypt and decrypt" {
    key_buf = @splat(0x42);
    const max: u128 = 1000;
    const x: u128 = 7;
    writeU128(io_buf[0..2], x);
    writeU128(io_buf[2..4], max);
    try std.testing.expectEqual(@as(u32, 0), runEncrypt(6));
    const c = readU128(io_buf[4], io_buf[5]);
    try std.testing.expectEqual(ffsem.encrypt(x, max, key_buf, 6), c);
    try std.testing.expect(io_buf[8] >= 6);

    writeU128(io_buf[0..2], c);
    try std.testing.expectEqual(@as(u32, 0), runDecrypt(6));
    const p = readU128(io_buf[4], io_buf[5]);
    try std.testing.expectEqual(x, p);
}
