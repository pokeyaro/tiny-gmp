//! Random number generation and shuffling utilities
//!
//! Provides Fisher-Yates shuffle algorithm and cheap random number generation
//! for scheduler debugging and testing purposes.

const std = @import("std");

/// Returns a random index in the range [0, n); n must be > 0.
pub fn cheaprandIndex(n: usize) usize {
    std.debug.assert(n > 0);
    // Use OS-seeded CSPRNG; no manual seeding or globals needed.
    return std.crypto.random.intRangeLessThan(usize, 0, n);
}

/// Forward Fisher–Yates shuffle:
/// i goes from 1 → len-1, j ∈ [0, i].
fn shuffleForward(comptime T: type, slice: []T) void {
    if (slice.len <= 1) return;
    var i: usize = 1;
    while (i < slice.len) : (i += 1) {
        const j = cheaprandIndex(i + 1);
        std.mem.swap(T, &slice[i], &slice[j]);
    }
}

/// Reverse (classic) Fisher–Yates shuffle:
/// i goes from len-1 → 1, j ∈ [0, i].
fn shuffleReverse(comptime T: type, slice: []T) void {
    if (slice.len <= 1) return;
    var i: usize = slice.len - 1;
    while (i > 0) : (i -= 1) {
        const j = cheaprandIndex(i + 1);
        std.mem.swap(T, &slice[i], &slice[j]);
    }
}

/// Public shuffle function — uses the classic reverse implementation.
pub fn shuffleBatch(comptime T: type, slice: []T) void {
    shuffleReverse(T, slice);
}
