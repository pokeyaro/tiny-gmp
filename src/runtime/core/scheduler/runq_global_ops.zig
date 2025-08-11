// =====================================================
// Global Queue Operations
// =====================================================

pub fn bind(comptime Self: type) type {
    const std = @import("std");
    const goroutine = @import("../../entity/goroutine.zig");
    const processor = @import("../../entity/processor.zig");

    const G = goroutine.G;
    const P = processor.P;

    return struct {
        /// Add a goroutine to the global run queue.
        /// Matches Go's globrunqput() function.
        /// Note: Adapted to use batch interface for performance consistency.
        pub fn globrunqput(self: *Self, gp: *G) void {
            // Clear goroutine scheduling link
            gp.clearLink();

            // Put in global queue using batch interface (single element).
            // This maintains consistency with global queue's batch-oriented design.
            var single_batch = [_]*G{gp};
            self.runq.enqueueBatch(&single_batch);

            // TODO: Check if need to wake idle P.
            if (self.hasIdleProcessors()) {
                // Has idle P, might need to wake one to handle.
                // self.wakep();  // Future implementation.
            }
        }

        /// Get a batch of goroutines from the global run queue.
        /// Matches Go's globrunqget() function.
        pub fn globrunqget(self: *Self, pp: *P, max: usize) ?*G {
            if (self.isEmpty()) return null;

            // Use half of the local capacity as a safety bound.
            const local_cap_half = pp.runq.capacity() / 2;

            // Determine the initial candidate batch size.
            var n = self.calculateBatchSize(max, local_cap_half);

            // Tighten with the actual available slots of the local queue.
            const available = pp.runq.capacity() - pp.runq.size();
            n = @min(n, available);

            // Defensive: if n == 0, nothing to pull.
            if (n == 0) return null;

            // We assert the precondition before dequeue; enqueue should not fail.
            std.debug.assert(n <= available);

            // Pull a batch from the global queue.
            const batch = self.runq.dequeueBatch(n);

            // Transfer batch to local queue (should not fail given the checks above).
            if (!batch.isEmpty()) {
                pp.runq.enqueueBatch(batch) catch {
                    // Truly unreachable if the pre-checks are correct.
                    unreachable;
                };
            }

            return batch.immediate_g;
        }

        /// Calculate optimal batch size for load balancing.
        /// Matches Go's batch size calculation algorithm.
        fn calculateBatchSize(self: *Self, max: usize, local_cap_half: usize) usize {
            const qs = self.runqsize();
            if (qs == 0) return 0;

            var n = qs / self.nproc + 1; // Base on even distribution + 1.
            if (n > qs / 2) n = qs / 2; // No more than half of global queue.
            if (max > 0 and n > max) n = max; // Limit only when caller explicitly specifies max.
            if (n > local_cap_half) n = local_cap_half; // Local half-capacity protection.

            return n;
        }
    };
}
