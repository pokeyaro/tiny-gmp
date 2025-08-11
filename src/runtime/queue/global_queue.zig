//! Global scheduler queue implementation
//!
//! Centralized goroutine queue using direct schedlink chaining for zero-copy
//! batch operations. Provides efficient work distribution between processors
//! with overflow handling and load balancing capabilities.

const std = @import("std");
const goroutine = @import("../gmp/goroutine.zig");

// Import types
const G = goroutine.G;

// =====================================================
// Global Queue - Business Layer Queue for Goroutines
// =====================================================

/// Batch result for efficient goroutine transfer between queues.
/// Simplified design using direct G.schedlink chaining.
pub const GlobalRunqBatch = struct {
    immediate_g: ?*G = null, // First goroutine to run immediately.
    batch_head: ?*G = null, // Head of the remaining batch (linked via G.schedlink).
    batch_count: usize = 0, // Number of goroutines in the linked batch.

    /// Returns true if both immediate_g and batch_head are null.
    pub fn isEmpty(self: *const GlobalRunqBatch) bool {
        return self.immediate_g == null and self.batch_head == null;
    }

    /// Total goroutines in this batch (immediate + linked batch).
    pub fn totalCount(self: *const GlobalRunqBatch) usize {
        const immediate_count: usize = if (self.immediate_g != null) 1 else 0;
        return immediate_count + self.batch_count;
    }
};

/// Global queue for goroutine scheduling.
/// Uses direct G.schedlink chaining, matching Go's actual implementation.
///
/// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "type gQueue struct").
pub const GlobalQueue = struct {
    const Self = @This();

    head: ?*G = null, // Head of the goroutine chain.
    tail: ?*G = null, // Tail of the goroutine chain.
    count: usize = 0, // Matches Go's sched.runqsize.

    // A small return type for cut helpers.
    const Cut = struct {
        head: *G,
        tail: *G,
        len: usize,
    };

    /// Initialize a new empty global queue.
    pub fn init() Self {
        return Self{
            .head = null,
            .tail = null,
            .count = 0,
        };
    }

    /// Clear the queue (no memory deallocation needed).
    pub fn deinit(self: *Self) void {
        self.clear();
    }

    /// Check if the queue is empty.
    pub fn isEmpty(self: *const Self) bool {
        return self.head == null;
    }

    /// Get the number of goroutines in the queue (O(1) operation).
    pub fn size(self: *const Self) usize {
        return self.count;
    }

    /// Add a single goroutine to the global queue.
    pub fn enqueue(self: *Self, g: *G) void {
        g.clearLink(); // Ensure clean state

        if (self.tail) |tail| {
            tail.linkTo(g);
            self.tail = g;
        } else {
            // Empty queue
            self.head = g;
            self.tail = g;
        }
        self.count += 1;
    }

    /// Remove a single goroutine from the global queue.
    pub fn dequeue(self: *Self) ?*G {
        const g = self.head orelse return null;

        self.head = g.schedlink;
        if (self.head == null) self.tail = null; // Queue becomes empty.

        g.clearLink(); // Clean up the removed goroutine.
        self.count -= 1;
        return g;
    }

    /// Add multiple goroutines to the global queue.
    /// Used when local queue overflows to global queue.
    pub fn enqueueBatch(self: *Self, goroutines: []*G) void {
        if (goroutines.len == 0) return;

        // Pre-build the chain (one-time operation).
        for (goroutines, 0..) |g, i| {
            g.clearLink();
            if (i < goroutines.len - 1) {
                g.linkTo(goroutines[i + 1]);
            }
        }

        // Connect to global queue in one operation (only update head/tail pointers once).
        if (self.tail) |tail| {
            tail.linkTo(goroutines[0]);
        } else {
            self.head = goroutines[0];
        }
        self.tail = goroutines[goroutines.len - 1];
        self.count += goroutines.len;
    }

    /// Get a batch of goroutines from the global queue.
    pub fn dequeueBatch(self: *Self, n: usize) GlobalRunqBatch {
        var out = GlobalRunqBatch{};
        if (self.isEmpty() or n == 0) return out;

        // Ensure we don't take more than available.
        const take_n = @min(n, self.count);

        // Take the first one for immediate execution.
        out.immediate_g = self.dequeue(); // updates head/tail/count internally.

        // Get remaining goroutines as linked segment.
        if (take_n > 1) {
            const batch_len = take_n - 1;

            // Fast path: take all remaining in O(1).
            if (batch_len == self.count) {
                if (self.cutAll()) |seg| {
                    out.batch_head = seg.head;
                    out.batch_count = seg.len;
                }
                return out;
            }

            // General path: cut the first `batch_len` nodes from the remaining queue.
            const seg = self.cutPrefix(batch_len);
            out.batch_head = seg.head;
            out.batch_count = seg.len;
        }

        return out;
    }

    /// Remove all goroutines from the queue.
    pub fn clear(self: *Self) void {
        // Clear all links (optional, for cleanliness).
        var current = self.head;
        while (current) |g| {
            const next = g.schedlink;
            g.clearLink();
            current = next;
        }

        self.head = null;
        self.tail = null;
        self.count = 0;
    }

    /// Display global queue state for debugging.
    pub fn display(self: *const Self) void {
        std.debug.print("GlobalQueue: ", .{});

        var current = self.head;
        var first = true;
        while (current) |g| {
            if (!first) std.debug.print(" -> ", .{});
            std.debug.print("G{}", .{g.id});
            current = g.schedlink;
            first = false;
        }

        std.debug.print(" (count: {})\n", .{self.count});
    }

    // ======== private helpers ========

    /// Cut and return a prefix of exactly k nodes from the front of the queue.
    /// Cost: O(k). Requires 1 <= k <= self.count.
    fn cutPrefix(self: *Self, k: usize) Cut {
        std.debug.assert(k >= 1 and k <= self.count);

        const head_ptr = self.head.?;
        var tail_ptr = head_ptr;

        var i: usize = 1;
        while (i < k) : (i += 1) {
            tail_ptr = tail_ptr.schedlink.?;
        }

        // Detach [head_ptr .. tail_ptr].
        self.head = tail_ptr.schedlink;
        tail_ptr.clearLink();

        if (self.head == null) self.tail = null;

        self.count -= k;
        return .{ .head = head_ptr, .tail = tail_ptr, .len = k };
    }

    /// Cut and return the entire remaining chain (O(1)). Returns null if empty.
    fn cutAll(self: *Self) ?Cut {
        if (self.count == 0) return null;

        const h = self.head.?;
        const t = self.tail.?;
        const n = self.count;

        self.head = null;
        self.tail = null;
        self.count = 0;

        // Ensure the returned segment is closed.
        t.clearLink();
        return .{ .head = h, .tail = t, .len = n };
    }
};
