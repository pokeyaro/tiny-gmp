const std = @import("std");
const goroutine = @import("goroutine.zig");
const local_queue = @import("../queue/local_queue.zig");

// Import types
const G = goroutine.G;
const LocalQueue = local_queue.LocalQueue;

// =====================================================
// P (Processor) Definitions
// =====================================================

var next_pid: u32 = 0; // P ID counter

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

/// Result type returned by runqget function.
/// Contains the goroutine and information about its source.
pub const RunqResult = struct {
    g: ?*G,
    from_runnext: bool,

    pub fn sourceName(self: RunqResult) []const u8 {
        return if (self.from_runnext) "runnext" else "runq";
    }
};

/// P represents a processor, which manages goroutine scheduling.
/// This follows Go's GMP model where P is the logical processor.
///
/// Go source: https://github.com/golang/go/blob/master/src/runtime/runtime2.go (search for "type p struct")
pub const P = struct {
    id: u32, // Unique processor ID
    status: PStatus = .Idle, // Execution status
    runq: LocalQueue, // Local run queue (corresponds to Go's runq)
    runnext: ?*G = null, // Fast-path slot for next G (corresponds to Go's runnext)

    /// Create a new processor with an empty run queue and a unique ID.
    pub fn init() P {
        const pid = next_pid;
        next_pid += 1;
        return P{
            .id = pid,
            .status = .Idle,
            .runq = LocalQueue.init(),
            .runnext = null,
        };
    }

    /// Check if the runnext slot has a goroutine waiting.
    /// Returns true if runnext is occupied.
    pub fn hasRunnext(self: *const P) bool {
        return self.runnext != null;
    }

    /// Get the total number of goroutines managed by this processor.
    /// This includes both the main queue and the runnext slot.
    pub fn totalGoroutines(self: *const P) usize {
        const queue_size = self.runq.size();
        const runnext_size: usize = if (self.hasRunnext()) 1 else 0;
        return queue_size + runnext_size;
    }

    /// Check if the processor has work to do.
    /// Returns true if there are goroutines to execute.
    pub fn hasWork(self: *const P) bool {
        return !self.runq.isEmpty() or self.hasRunnext();
    }

    /// Add a goroutine to this processor's run queue.
    /// Uses the runnext optimization: new goroutines go to runnext first.
    /// Returns true if successful, false if processor is full.
    ///
    /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func runqput")
    pub fn runqput(self: *P, g: *G) bool {
        // Fast path: use runnext if available
        if (!self.hasRunnext()) {
            self.runnext = g;
            return true;
        }

        // Slow path: try to add to the main queue
        // If queue is full, we might need to implement more complex logic
        return self.runq.enqueue(g);
    }

    /// Get the next goroutine to execute from this processor.
    /// Prioritizes runnext (fast path) over the main queue.
    /// Returns null if no goroutines are available.
    ///
    /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func runqget")
    ///
    /// Implementation Strategy: "Passive Replenishment"
    /// This implementation follows Go's actual strategy of passive runnext replenishment.
    /// When runnext is consumed, it remains empty until a new goroutine is scheduled.
    ///
    /// Alternative Strategy (NOT used): "Active Promotion"
    /// An alternative would be to actively promote a goroutine from runq to runnext
    /// when runnext is consumed, but this approach has drawbacks:
    /// - Increased complexity and potential for bugs
    /// - Additional overhead on every dequeue operation
    /// - May reduce fairness by keeping some goroutines at the back of runq
    /// - Not how Go actually implements it
    ///
    /// Why Passive Replenishment is Better:
    /// - Simpler and more reliable implementation
    /// - runnext serves its intended purpose: fast path for newly created goroutines
    /// - Maintains fairness in goroutine scheduling
    /// - Consistent with Go's design philosophy of simplicity
    /// - New goroutines are created frequently enough that runnext won't stay empty long
    ///
    /// This design choice aligns with Go's runtime implementation and ensures our
    /// educational GMP model accurately reflects the real scheduler behavior.
    pub fn runqget(self: *P) RunqResult {
        // Fast path: check runnext first
        if (self.runnext) |g| {
            self.runnext = null; // Simply clear runnext, no active replenishment
            return .{ .g = g, .from_runnext = true };
        }

        // Slow path: get from main queue (runnext stays empty until new goroutines arrive)
        return .{ .g = self.runq.dequeue(), .from_runnext = false };
    }

    /// Set the processor status.
    pub fn setStatus(self: *P, status: PStatus) void {
        self.status = status;
    }

    /// Synchronize processor status with its actual work state.
    /// Sets status to Idle if no work available, otherwise keeps current status.
    pub fn syncStatus(self: *P) void {
        if (!self.hasWork()) {
            self.setStatus(.Idle);
        }
    }

    /// Check if the processor is idle.
    pub fn isIdle(self: *const P) bool {
        return self.status == .Idle and !self.hasWork();
    }

    /// Check if the processor is running.
    pub fn isRunning(self: *const P) bool {
        return self.status == .Running;
    }

    /// Display processor state showing runnext and queue separately.
    /// Output format: P0: next: G5; queue: [G1, G2, G3]
    pub fn display(self: *const P) void {
        std.debug.print("P{}: next: ", .{self.id});

        // Show runnext slot
        if (self.runnext) |g| {
            std.debug.print("G{}", .{g.id});
        } else {
            std.debug.print("_", .{});
        }

        std.debug.print("; queue: ", .{});

        // Show queue contents using LocalQueue's display
        self.runq.display();

        std.debug.print("\n", .{});
    }
};
