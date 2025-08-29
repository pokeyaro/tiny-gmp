// =====================================================
// Scheduler Types
// =====================================================

const tg = @import("../../tg.zig");

// Types
const G = tg.G;

/// Source of a goroutine when it gets selected to run.
pub const GSrc = enum {
    Runnext,
    Runq,
    Global,

    /// Convert a GSrc enum to a human-readable string.
    pub fn toString(self: GSrc) []const u8 {
        return switch (self) {
            .Runnext => "runnext",
            .Runq => "runq",
            .Global => "global",
        };
    }
};

/// Result type returned by runqget function.
/// Contains the goroutine and information about its source.
pub const WorkItem = struct {
    pub const Self = @This();

    g: *G,
    src: GSrc,

    /// Typed source accessor.
    pub fn source(self: Self) GSrc {
        return self.src;
    }

    /// Human-readable source label.
    pub fn sourceName(self: Self) []const u8 {
        return self.src.toString();
    }
};

/// Timer entry bound to scheduler "ticks".
/// When `deadline` ≤ current `ticks`, the goroutine should be unparked.
pub const TimerEntry = struct {
    g: *G,
    deadline: u64, // measured in scheduler ticks
};
