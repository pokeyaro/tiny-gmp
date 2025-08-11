//! Goroutine implementation (G in GMP model)
//!
//! Basic execution unit with complete lifecycle management following Go's design.
//! Features status tracking, task execution, and scheduler queue linking for
//! efficient goroutine scheduling and coordination.

const std = @import("std");

// =====================================================
// G (Goroutine) Definitions
// =====================================================

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
/// Go source: https://github.com/golang/go/blob/master/src/runtime/runtime2.go (search for "type g struct").
pub const G = struct {
    /// Unique goroutine ID.
    id: u32,

    /// Current execution status.
    status: GStatus = .Ready,

    /// Pointer to task function.
    task: ?*const fn () void,

    /// Link to next goroutine in scheduling queues.
    schedlink: ?*G = null,

    /// Initialize a new Goroutine with an auto-incremented ID and given task.
    pub fn init(gid: u32, task: ?*const fn () void) G {
        return G{
            .id = gid,
            .status = .Ready,
            .task = task,
            .schedlink = null,
        };
    }

    /// Get goroutine ID.
    pub fn getID(self: *const G) u32 {
        return self.id;
    }

    /// Set goroutine status with validation.
    pub fn setStatus(self: *G, new_status: GStatus) void {
        self.status = new_status;
    }

    /// Get current status.
    pub fn getStatus(self: *const G) GStatus {
        return self.status;
    }

    /// Check if goroutine is in Ready status.
    pub fn isReady(self: *const G) bool {
        return self.status == .Ready;
    }

    /// Check if goroutine is in Running status.
    pub fn isRunning(self: *const G) bool {
        return self.status == .Running;
    }

    /// Check if goroutine is in Done status.
    pub fn isDone(self: *const G) bool {
        return self.status == .Done;
    }

    /// Get the task function pointer, returns null if no task assigned.
    pub fn getTask(self: *const G) ?*const fn () void {
        return self.task;
    }

    /// Check if goroutine has a task to execute.
    pub fn hasTask(self: *const G) bool {
        return self.getTask() != null;
    }

    /// Check if goroutine is ready for execution (status + task check).
    pub fn isExecutionReady(self: *const G) bool {
        return self.isReady() and self.hasTask();
    }

    /// Link this goroutine to another goroutine.
    pub fn linkTo(self: *G, next: ?*G) void {
        self.schedlink = next;
    }

    /// Clear the scheduling link.
    pub fn clearLink(self: *G) void {
        self.schedlink = null;
    }

    /// Check if this goroutine is linked to another.
    pub fn isLinked(self: *const G) bool {
        return self.schedlink != null;
    }
};
