const std = @import("std");

// =====================================================
// G (Goroutine) Definitions
// =====================================================

var next_gid: u32 = 0; // G ID counter

/// Status enum for Goroutine lifecycle.
pub const GStatus = enum {
    Ready, // Waiting to be scheduled
    Running, // Currently executing
    Done, // Finished execution

    /// Convert a GStatus enum to a human-readable string.
    pub fn toString(self: GStatus) []const u8 {
        return switch (self) {
            .Ready => "Ready",
            .Running => "Running",
            .Done => "Done",
        };
    }
};

/// G represents a goroutine, the basic unit of execution.
/// This follows Go's GMP model where G is the goroutine.
///
/// Go source: https://github.com/golang/go/blob/master/src/runtime/runtime2.go (search for "type g struct")
pub const G = struct {
    id: u32, // Unique goroutine ID
    status: GStatus = .Ready, // Current execution status
    task: ?*const fn () void, // Pointer to task function

    /// Initialize a new Goroutine with an auto-incremented ID and given task.
    pub fn init(task: ?*const fn () void) G {
        const gid = next_gid;
        next_gid += 1;
        return G{
            .id = gid,
            .status = .Ready,
            .task = task,
        };
    }
};
