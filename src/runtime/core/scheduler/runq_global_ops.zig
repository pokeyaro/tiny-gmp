// =====================================================
// Global Queue Operations
// =====================================================

const std = @import("std");
const tg = @import("../../tg.zig");

// Types
const G = tg.G;
const P = tg.P;

pub fn bind(comptime Self: type, comptime WorkItem: type) type {
    return struct {
        /// Add a goroutine to the global run queue.
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func globrunqput").
        pub fn globrunqput(self: *Self, gp: *G) void {
            // Clear goroutine scheduling link.
            gp.clearLink();

            // Put in global queue using batch interface (single element).
            var single_batch = [_]*G{gp};
            self.runq.enqueueBatch(&single_batch);

            // Wake idle processors to handle new work.
            self.wakeForNewWork(1);
        }

        /// Get a batch of goroutines from the global run queue.
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func globrunqget").
        pub fn globrunqget(self: *Self, pp: *P, max: usize) ?*G {
            if (self.isEmpty()) return null;

            // Use half of the local capacity as a safety bound to prevent overflow.
            const local_cap_half = pp.runq.capacity() / 2;

            // Determine the initial candidate batch size.
            var n = self.calculateBatchSize(max, local_cap_half);

            // Check actual available space in target processor's local queue.
            const available = pp.runq.available();
            if (available == 0) return null; // Local queue is full.

            // Ensure we have at least 1 goroutine and don't exceed available space.
            if (n == 0) n = 1;
            n = @min(n, available);
            std.debug.assert(n > 0);

            // Safety check: batch size should never exceed available space.
            std.debug.assert(n <= available);

            // Pull the calculated batch from global queue.
            const batch = self.runq.dequeueBatch(n);

            // Transfer batch to processor's local queue for future scheduling.
            if (!batch.isEmpty()) {
                pp.runq.enqueueBatch(batch) catch {
                    // This should never fail due to our capacity checks above.
                    unreachable;
                };
            }

            // Return the first goroutine for immediate execution.
            return batch.immediate_g;
        }

        /// Convenience wrapper over `globrunqget` that returns a `WorkItem`.
        pub fn globrunqgetWorkItem(self: *Self, p: *P) ?WorkItem {
            if (self.globrunqget(p, 0)) |g| {
                return .{ .g = g, .src = .Global };
            }
            return null;
        }

        /// Wake idle processors when new work is added to global queue.
        /// This implements the scheduler's load balancing strategy by ensuring
        /// idle processors can immediately pick up newly available work.
        pub fn wakeForNewWork(self: *Self, work_count: u32) void {
            if (self.hasIdleProcessors()) {
                _ = self.tryWake(@min(work_count, self.getIdleCount()));
            }
        }

        // === Private Helper Methods ===

        /// Calculate optimal batch size for load balancing.
        /// Matches Go's batch size calculation algorithm.
        fn calculateBatchSize(self: *Self, max: usize, local_cap_half: usize) usize {
            const qs = self.runqsize();
            if (qs == 0) return 0;

            var n = qs / self.processorCount() + 1; // Based on even distribution + 1.
            if (n > qs / 2) n = qs / 2; // Take at most half of the global queue.
            if (max > 0 and n > max) n = max; // Obey caller’s limit.
            if (n > local_cap_half) n = local_cap_half; // Guard: don’t overfill local runq.
            if (n < 1) n = 1; // At least one when qs > 0.

            return n;
        }
    };
}
