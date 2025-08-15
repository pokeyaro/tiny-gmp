//! Random utilities
//!
//! Provides lightweight random helpers for scheduler and other modules.
//! Currently includes generating a random index in the range [0, n).

const std = @import("std");

/// Returns a random index in the range [0, n).
/// Requires: n > 0; if n == 0, a debug assertion will trigger
/// (this indicates a logic error in the caller).
pub fn cheapRandIndex(n: usize) usize {
    std.debug.assert(n > 0);
    // Use OS-seeded CSPRNG; no manual seeding or globals needed.
    return std.crypto.random.intRangeLessThan(usize, 0, n);
}
