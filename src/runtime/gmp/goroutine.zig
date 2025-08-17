//! Goroutine implementation (G in GMP model)
//!
//! Basic execution unit with complete lifecycle management following Go's design.
//! Features status tracking, task execution, and scheduler queue linking for
//! efficient goroutine scheduling and coordination.

const std = @import("std");

// =============================
// Public enums / small structs
// =============================

/// Status enum for Goroutine lifecycle.
pub const GStatus = enum {
    Ready, // Waiting to be scheduled.
    Running, // Currently executing.
    Done, // Finished execution.

    /// Convert a GStatus enum to a human-readable string.
    pub fn toString(self: GStatus) []const u8 {
        return @tagName(self);
    }
};

/// The reason why a goroutine last yielded control back to the scheduler.
pub const YieldReason = enum(u8) {
    TimeSlice, // Yielded because its time slice expired.
    Preempt, // Yielded due to a preemption request.
    Syscall, // Yielded because it entered a blocking syscall.
    IO, // Yielded for I/O wait.
    Unknown, // Reason not specified.

    /// Convert a YieldReason to a human-readable string.
    pub fn toString(self: YieldReason) []const u8 {
        return @tagName(self);
    }
};

/// Scheduling context used by the runtime to track preemption state.
pub const SchedCtx = struct {
    /// Indicates whether this goroutine has been marked for preemption.
    preempt: bool = false,

    /// Records the reason for the last yield; used for diagnostics/metrics.
    last_yield_reason: YieldReason = .Unknown,
};

// =============================
// Goroutine definition
// =============================

/// G represents a goroutine, the basic unit of execution.
/// This follows Go's GMP model where G is the goroutine.
///
/// Go source: https://github.com/golang/go/blob/master/src/runtime/runtime2.go (search for "type g struct").
pub const G = struct {
    const Self = @This();

    // === Core fields ===

    /// Unique goroutine ID.
    id: u64,

    /// Current execution status.
    status: GStatus = .Ready,

    /// Pointer to task function.
    task: ?*const fn () void,

    /// Link to next goroutine in scheduling queues.
    schedlink: ?*Self = null,

    /// Per-goroutine scheduling state.
    sched: SchedCtx = .{},

    // === Constructors ===

    /// Initialize a new Goroutine with an auto-incremented ID and given task.
    pub fn init(gid: u64, task: ?*const fn () void) Self {
        return .{
            .id = gid,
            .status = .Ready,
            .task = task,
            .schedlink = null,
            .sched = .{},
        };
    }

    // === Accessors: identity ===

    /// Get goroutine ID.
    pub fn getID(self: *const Self) u64 {
        return self.id;
    }

    // === Accessors: status ===

    /// Get current status.
    pub fn getStatus(self: *const Self) GStatus {
        return self.status;
    }

    /// Set goroutine status with validation.
    pub fn setStatus(self: *Self, new_status: GStatus) void {
        self.status = new_status;
    }

    /// Check if goroutine is in Ready status.
    pub fn isReady(self: *const Self) bool {
        return self.status == .Ready;
    }

    /// Check if goroutine is in Running status.
    pub fn isRunning(self: *const Self) bool {
        return self.status == .Running;
    }

    /// Check if goroutine is in Done status.
    pub fn isDone(self: *const Self) bool {
        return self.status == .Done;
    }

    // === Accessors: task ===

    /// Get the task function pointer, returns null if no task assigned.
    pub fn getTask(self: *const Self) ?*const fn () void {
        return self.task;
    }

    /// Check if goroutine has a task to execute.
    pub fn hasTask(self: *const Self) bool {
        return self.getTask() != null;
    }

    // === Accessors: readiness ===

    /// Check if goroutine is ready for execution (status + task check).
    pub fn isExecutionReady(self: *const Self) bool {
        return self.isReady() and self.hasTask();
    }

    // === Scheduling link helpers ===

    /// Link this goroutine to another goroutine.
    pub fn linkTo(self: *Self, next: ?*Self) void {
        self.schedlink = next;
    }

    /// Clear the scheduling link.
    pub fn clearLink(self: *Self) void {
        self.schedlink = null;
    }

    /// Check if this goroutine is linked to another.
    pub fn isLinked(self: *const Self) bool {
        return self.schedlink != null;
    }

    // === Scheduling preemption helpers ===

    /// Mark this goroutine to be preempted at the next safe point.
    pub fn requestPreempt(self: *Self) void {
        self.setPreemptRequested(true);
    }

    /// Consume a pending preemption request at a safe point.
    /// Returns true if the goroutine was marked for preemption.
    pub fn consumePreempt(self: *Self) bool {
        if (!self.isPreemptRequested()) {
            return false;
        }
        self.setPreemptRequested(false);
        self.setLastYieldReason(.Preempt);
        return true;
    }

    /// Is preemption currently requested?
    pub fn isPreemptRequested(self: *const Self) bool {
        return self.sched.preempt;
    }

    /// Set/clear the preemption request flag.
    pub fn setPreemptRequested(self: *Self, v: bool) void {
        self.sched.preempt = v;
    }

    // === Scheduling diagnostics helpers ===

    /// Return last yield reason (enum).
    pub fn getLastYieldReason(self: *const Self) YieldReason {
        return self.sched.last_yield_reason;
    }

    /// Set last yield reason.
    pub fn setLastYieldReason(self: *Self, r: YieldReason) void {
        self.sched.last_yield_reason = r;
    }

    /// Return last yield reason as string.
    pub fn getLastYieldReasonStr(self: *const Self) []const u8 {
        return self.getLastYieldReason().toString();
    }
};
