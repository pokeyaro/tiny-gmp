//! Processor implementation (P in GMP model)
//!
//! Logical processor that manages local goroutine scheduling with fast-path optimization.
//! Features runnext slot for newly created goroutines and local run queue for efficient
//! work distribution. Provides comprehensive state management and debugging capabilities.

const std = @import("std");
const tg = @import("../tg.zig");

// Types
const G = tg.G;
const LocalQueue = tg.queue.local_queue.LocalQueue;

// =====================================================
// P (Processor) Definitions
// =====================================================

/// Status enum for Processor (P).
pub const PStatus = enum {
    Idle, // No work assigned
    Running, // Actively executing Gs

    /// Convert a PStatus enum to a human-readable string.
    pub fn toString(self: PStatus) []const u8 {
        return switch (self) {
            .Idle => "Idle",
            .Running => "Running",
        };
    }
};

/// P represents a processor, which manages goroutine scheduling.
/// This follows Go's GMP model where P is the logical processor.
///
/// Go source: https://github.com/golang/go/blob/master/src/runtime/runtime2.go (search for "type p struct").
pub const P = struct {
    /// Unique processor ID.
    id: u32,

    /// Execution status.
    status: PStatus = .Idle,

    /// Local run queue (corresponds to Go's runq).
    runq: LocalQueue,

    /// Fast-path slot for next G (corresponds to Go's runnext).
    runnext: ?*G = null,

    /// Link to next processor in intrusive linked list.
    /// Corresponds to Go's P.link field (used for pidle etc.).
    /// null when P is not in any linked list.
    link: ?*P = null,

    /// Create a new processor with an empty run queue and a unique ID.
    pub fn init(pid: u32) P {
        return P{
            .id = pid,
            .status = .Idle,
            .runq = LocalQueue.init(),
            .runnext = null,
            .link = null,
        };
    }

    /// Get processor ID.
    pub fn getID(self: *const P) u32 {
        return self.id;
    }

    /// Get the goroutine in runnext slot.
    /// Returns the goroutine pointer or null if empty.
    pub fn getRunnext(self: *const P) ?*G {
        return self.runnext;
    }

    /// Set the processor status.
    pub fn setStatus(self: *P, status: PStatus) void {
        self.status = status;
    }

    /// Check if the processor is idle.
    pub fn isIdle(self: *const P) bool {
        return self.status == .Idle and !self.hasWork();
    }

    /// Check if the processor is running.
    pub fn isRunning(self: *const P) bool {
        return self.status == .Running;
    }

    /// Synchronize processor status with its actual work state.
    /// Sets status to Idle if no work available, otherwise keeps current status.
    pub fn syncStatus(self: *P) void {
        if (!self.hasWork()) self.setStatus(.Idle);
    }

    /// Check if the runnext slot has a goroutine waiting.
    /// Returns true if runnext is occupied.
    pub fn hasRunnext(self: *const P) bool {
        return self.runnext != null;
    }

    /// Set a goroutine to the runnext slot.
    /// Overwrites any existing goroutine in the slot.
    pub fn setRunnext(self: *P, g: ?*G) void {
        self.runnext = g;
    }

    /// Clear the runnext slot.
    /// Convenience method equivalent to setRunnext(null).
    pub fn clearRunnext(self: *P) void {
        self.runnext = null;
    }

    /// Try to add a goroutine to the local run queue.
    /// Returns true if successful, false if queue is full.
    pub fn localEnqueue(self: *P, g: *G) bool {
        return self.runq.enqueue(g);
    }

    /// Check if the processor has work to do.
    /// Returns true if there are goroutines to execute.
    pub fn hasWork(self: *const P) bool {
        return !self.runq.isEmpty() or self.hasRunnext();
    }

    /// Get the total number of goroutines managed by this processor.
    /// This includes both the main queue and the runnext slot.
    pub fn totalGoroutines(self: *const P) usize {
        const queue_size = self.runq.size();
        const runnext_size: usize = if (self.hasRunnext()) 1 else 0;
        return queue_size + runnext_size;
    }

    /// Link this processor to another processor (for idle stack).
    pub fn linkTo(self: *P, next: ?*P) void {
        self.link = next;
    }

    /// Clear the processor link.
    pub fn clearLink(self: *P) void {
        self.link = null;
    }

    /// Check if this processor is linked to another.
    pub fn isLinked(self: *const P) bool {
        return self.link != null;
    }

    /// Display processor state showing runnext and queue separately.
    /// Output format: P0: next: G5; queue: [G1, G2, G3].
    pub fn display(self: *const P) void {
        std.debug.print("P{}: next: ", .{self.id});

        // Show runnext slot.
        if (self.runnext) |g| {
            std.debug.print("G{}", .{g.id});
        } else {
            std.debug.print("_", .{});
        }

        std.debug.print("; queue: ", .{});

        // Show queue contents using LocalQueue's display.
        self.runq.display();

        std.debug.print("\n", .{});
    }
};
