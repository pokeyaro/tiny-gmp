const std = @import("std");
const goroutine = @import("goroutine.zig");

// Import G type from goroutine module
const G = goroutine.G;

// =====================================================
// P (Processor) Definitions
// =====================================================

const RUNQ_SIZE = 256; // Local run queue size constant

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

/// P represents a processor, which manages its own goroutine queue.
pub const P = struct {
    id: u32, // Unique processor ID
    status: PStatus = .Idle, // Execution status
    runq: [RUNQ_SIZE]?*G, // Circular run queue
    runqhead: u32 = 0, // Head index of the run queue
    runqtail: u32 = 0, // Tail index of the run queue
    runnext: ?*G = null, // Fast-path slot for next G

    /// Create a new processor with an empty run queue and a unique ID.
    pub fn init() P {
        const pid = next_pid;
        next_pid += 1;
        return P{
            .id = pid,
            .status = .Idle,
            .runq = [_]?*G{null} ** RUNQ_SIZE,
            .runqhead = 0,
            .runqtail = 0,
            .runnext = null,
        };
    }

    /// Get the number of goroutines in the run queue.
    pub fn size(self: *const P) u32 {
        return (self.runqtail - self.runqhead) % RUNQ_SIZE;
    }

    /// Check if the processor has no goroutines left.
    pub fn isEmpty(self: *const P) bool {
        return self.size() == 0 and self.runnext == null;
    }

    /// Check if the run queue is full (excluding runnext slot).
    pub fn isFull(self: *const P) bool {
        return self.size() >= (RUNQ_SIZE - 1); // Reserve one slot as buffer
    }

    /// Attempt to enqueue a goroutine into the processor.
    /// Returns true if successful, false if full.
    pub fn enqueue(self: *P, g: *G) bool {
        if (self.runnext == null) {
            self.runnext = g;
            return true;
        }

        if (self.isFull()) return false;

        self.runq[self.runqtail % RUNQ_SIZE] = g;
        self.runqtail += 1;
        return true;
    }

    /// Dequeue the next runnable goroutine, prioritizing `runnext`.
    pub fn dequeue(self: *P) ?*G {
        if (self.runnext) |g| {
            self.runnext = null;
            return g;
        }

        if (self.size() == 0) return null;

        const g = self.runq[self.runqhead % RUNQ_SIZE];
        self.runq[self.runqhead % RUNQ_SIZE] = null;
        self.runqhead += 1;
        return g;
    }

    /// Print the current goroutine queue status of this processor.
    pub fn display(self: *const P) void {
        std.debug.print("P{}: [", .{self.id});

        var first = true;

        // Show the G in runnext
        if (self.runnext) |g| {
            std.debug.print("G{}", .{g.id});
            first = false;
        }

        // Show all Gs in the queue
        var i = self.runqhead;
        while (i != self.runqtail) {
            if (self.runq[i % RUNQ_SIZE]) |g| {
                if (!first) std.debug.print(", ", .{});
                std.debug.print("G{}", .{g.id});
                first = false;
            }
            i += 1;
        }

        std.debug.print("]\n", .{});
    }
};
