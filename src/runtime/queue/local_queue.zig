//! Local processor queue implementation
//!
//! Business layer wrapper around circular queue providing goroutine-specific
//! operations for processor-local scheduling. Handles batch transfers from
//! global queue and efficient goroutine storage with overflow management.

const std = @import("std");
const tg = @import("../tg.zig");

// Types
const G = tg.G;
const CircularQueue = tg.lib.ds.circular_queue.CircularQueue;
const GlobalRunqBatch = tg.queue.global_queue.GlobalRunqBatch;

// =====================================================
// Local Queue - Business Layer Queue for Goroutines
// =====================================================

pub const RUNQ_SIZE = 256; // P's local run queue size (same as Go).

/// Business-specific queue for managing goroutines in a processor.
/// This layer adds goroutine-specific logic on top of the generic circular queue.
pub const LocalQueue = struct {
    const Self = @This();
    pub const Error = error{LocalQueueFull};

    const Q = CircularQueue(*G, RUNQ_SIZE);

    queue: Q,

    /// Initialize a new empty local queue.
    pub fn init() Self {
        return .{
            .queue = CircularQueue(*G, RUNQ_SIZE).init(),
        };
    }

    /// Get the number of goroutines in the queue.
    /// This is a business-level size query.
    pub fn size(self: *const Self) usize {
        return self.queue.size();
    }

    /// Get the maximum capacity of the queue.
    pub fn capacity(self: *const Self) usize {
        return self.queue.maxCapacity();
    }

    /// Check if the queue is empty.
    pub fn isEmpty(self: *const Self) bool {
        return self.queue.isEmpty();
    }

    /// Check if the queue is full.
    pub fn isFull(self: *const Self) bool {
        return self.queue.isFull();
    }

    /// Get remaining capacity of the local run queue.
    /// Equivalent to `capacity() - size()`.
    pub fn available(self: *const Self) usize {
        return self.capacity() - self.size();
    }

    /// True if the queue still has at least one free slot.
    pub fn hasCapacity(self: *const Self) bool {
        return self.available() > 0;
    }

    /// Add a goroutine to the queue.
    /// Returns true if successful, false if queue is full.
    pub fn enqueue(self: *Self, g: *G) bool {
        if (self.queue.isFull()) {
            return false;
        }
        return self.queue.enqueue(g);
    }

    /// Add a batch of goroutines from GlobalRunqBatch to the local queue.
    /// Used when processor receives goroutines from global queue.
    pub fn enqueueBatch(self: *Self, batch: GlobalRunqBatch) !void {
        var current = batch.batch_head;
        while (current) |g| {
            const next = g.schedlink;
            if (!self.enqueue(g)) return Error.LocalQueueFull;
            g.clearLink();
            current = next;
        }
    }

    /// Remove and return the next goroutine from the queue.
    /// Returns null if queue is empty.
    pub fn dequeue(self: *Self) ?*G {
        return self.queue.dequeue();
    }

    /// Clear all goroutines from the queue.
    /// This might be used during processor shutdown or cleanup.
    pub fn clear(self: *Self) void {
        self.queue.clear();
    }

    /// Display the current state of the queue for debugging.
    /// Shows all goroutine IDs in the queue.
    /// Output format: [G1, G2, G3].
    pub fn display(self: *const Self) void {
        std.debug.print("[", .{});

        var first = true;
        self.queue.iterateWithCtx(&first, struct {
            fn callback(first_ptr: *bool, g: *G) void {
                if (!first_ptr.*) {
                    std.debug.print(", ", .{});
                }
                std.debug.print("G{}", .{g.getID()});
                first_ptr.* = false;
            }
        }.callback);

        std.debug.print("]", .{});
    }
};
