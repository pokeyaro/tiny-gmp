//! Local processor queue implementation
//!
//! Business layer wrapper around circular queue providing goroutine-specific
//! operations for processor-local scheduling. Handles batch transfers from
//! global queue and efficient goroutine storage with overflow management.

const std = @import("std");
const goroutine = @import("../gmp/goroutine.zig");
const circular_queue = @import("../../lib/ds/circular_queue.zig");
const global_queue = @import("global_queue.zig");

// Import types
const G = goroutine.G;
const CircularQueue = circular_queue.CircularQueue;
const GlobalRunqBatch = global_queue.GlobalRunqBatch;

// =====================================================
// Local Queue - Business Layer Queue for Goroutines
// =====================================================

pub const RUNQ_SIZE = 256; // P's local run queue size (same as Go).

/// Business-specific queue for managing goroutines in a processor.
/// This layer adds goroutine-specific logic on top of the generic circular queue.
pub const LocalQueue = struct {
    queue: CircularQueue(*G, RUNQ_SIZE),

    /// Initialize a new empty local queue.
    pub fn init() LocalQueue {
        return LocalQueue{
            .queue = CircularQueue(*G, RUNQ_SIZE).init(),
        };
    }

    /// Get the number of goroutines in the queue.
    /// This is a business-level size query.
    pub fn size(self: *const LocalQueue) usize {
        return self.queue.size();
    }

    /// Get the maximum capacity of the queue.
    pub fn capacity(self: *const LocalQueue) usize {
        return self.queue.maxCapacity();
    }

    /// Check if the queue is empty.
    pub fn isEmpty(self: *const LocalQueue) bool {
        return self.queue.isEmpty();
    }

    /// Check if the queue is full.
    pub fn isFull(self: *const LocalQueue) bool {
        return self.queue.isFull();
    }

    /// Add a goroutine to the queue.
    /// Returns true if successful, false if queue is full.
    pub fn enqueue(self: *LocalQueue, g: *G) bool {
        if (self.queue.isFull()) {
            return false;
        }
        return self.queue.enqueue(g);
    }

    /// Add a batch of goroutines from GlobalRunqBatch to the local queue.
    /// Used when processor receives goroutines from global queue.
    pub fn enqueueBatch(self: *LocalQueue, batch: GlobalRunqBatch) !void {
        // Iterate through the G.schedlink chain
        var current = batch.batch_head;
        while (current) |g| {
            const next = g.schedlink; // Save next goroutine.
            g.clearLink(); // Clear link (entering array-based queue).

            const success = self.enqueue(g);
            if (!success) return error.LocalQueueFull;

            current = next;
        }
    }

    /// Remove and return the next goroutine from the queue.
    /// Returns null if queue is empty.
    pub fn dequeue(self: *LocalQueue) ?*G {
        return self.queue.dequeue();
    }

    /// Clear all goroutines from the queue.
    /// This might be used during processor shutdown or cleanup.
    pub fn clear(self: *LocalQueue) void {
        self.queue.clear();
    }

    /// Display the current state of the queue for debugging.
    /// Shows all goroutine IDs in the queue.
    /// Output format: [G1, G2, G3].
    pub fn display(self: *const LocalQueue) void {
        std.debug.print("[", .{});

        var first = true;
        self.queue.iterateWithCtx(&first, struct {
            fn callback(first_ptr: *bool, g: *G) void {
                if (!first_ptr.*) {
                    std.debug.print(", ", .{});
                }
                std.debug.print("G{}", .{g.id});
                first_ptr.* = false;
            }
        }.callback);

        std.debug.print("]", .{});
    }
};
