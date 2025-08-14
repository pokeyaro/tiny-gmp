//! Shuffle utilities
//!
//! Implements the Fisher–Yates algorithm for generic slices.
//! This module focuses solely on sequence shuffling (in-place, O(n)).

const std = @import("std");
const random = @import("random.zig");

/// Public shuffle function — uses the classic reverse implementation.
pub fn shuffleBatch(comptime T: type, slice: []T) void {
    shuffleReverse(T, slice);
}

// === Internal helpers ===

/// Forward Fisher–Yates shuffle:
/// i goes from 1 → len-1, j ∈ [0, i].
fn shuffleForward(comptime T: type, slice: []T) void {
    if (slice.len <= 1) return;
    var i: usize = 1;
    while (i < slice.len) : (i += 1) {
        const j = random.cheaprandIndex(i + 1);
        std.mem.swap(T, &slice[i], &slice[j]);
    }
}

/// Reverse (classic) Fisher–Yates shuffle:
/// i goes from len-1 → 1, j ∈ [0, i].
fn shuffleReverse(comptime T: type, slice: []T) void {
    if (slice.len <= 1) return;
    var i: usize = slice.len - 1;
    while (i > 0) : (i -= 1) {
        const j = random.cheaprandIndex(i + 1);
        std.mem.swap(T, &slice[i], &slice[j]);
    }
}
