// =====================================================
// Local Queue Operations
// =====================================================

pub fn bind(comptime Self: type, comptime WorkItem: type) type {
    const std = @import("std");
    const goroutine = @import("../../gmp/goroutine.zig");
    const processor = @import("../../gmp/processor.zig");
    const local_queue = @import("../../queue/local_queue.zig");
    const shuffle = @import("../../../lib/algo/shuffle.zig");

    const G = goroutine.G;
    const P = processor.P;

    return struct {
        /// Put goroutine on local run queue.
        /// Uses the runnext optimization: new goroutines go to runnext first.
        /// Handles local queue overflow by transferring half to global queue.
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func runqput").
        pub fn runqput(self: *Self, p: *P, g: *G) void {
            // Fast path: use runnext if available.
            if (!p.hasRunnext()) {
                p.setRunnext(g);
                return;
            }

            // Slow path: try to add to the main queue.
            if (p.localEnqueue(g)) {
                return; // Successfully added to local queue.
            }

            // Local queue is full, transfer half to global queue.
            self.runqputslow(p, g);
        }

        /// Handle local queue overflow by transferring half to global queue.
        /// Called when both runnext and local queue are full.
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func runqputslow").
        fn runqputslow(self: *Self, p: *P, new_g: *G) void {
            const BATCH_SIZE: usize = local_queue.RUNQ_SIZE / 2 + 1;

            // Stack-allocated array with compile-time determined size.
            var batch: [BATCH_SIZE]*G = undefined;

            // Calculate how many goroutines to transfer (half of queue).
            const queue_size = p.runq.size();
            const transfer_count = queue_size / 2;

            // Defensive handling: should only be called when local queue is full.
            if (transfer_count == 0) {
                if (self.debug_mode) {
                    std.debug.print("Warning: runqputslow called on non-full queue\n", .{});
                }
                // Just put in global queue directly.
                self.globrunqput(new_g);
                return;
            }

            // Extract half of the goroutines from local queue (stack operation, no memory allocation).
            var actual_count: usize = 0;
            var i: usize = 0;
            while (i < transfer_count and actual_count < BATCH_SIZE - 1) : (i += 1) {
                if (p.runq.dequeue()) |gp| {
                    batch[actual_count] = gp;
                    actual_count += 1;
                } else {
                    break; // Queue became empty somehow.
                }
            }

            // half + the incoming new_g.
            batch[actual_count] = new_g;
            actual_count += 1;

            // Create slice pointing to stack array.
            const batch_slice = batch[0..actual_count];

            // Randomize scheduler in debug mode (mimics Go's randomizeScheduler).
            if (self.debug_mode) {
                shuffle.shuffleBatch(*G, batch_slice);
            }

            // Transfer the batch to global queue.
            self.runq.enqueueBatch(batch_slice);

            if (self.debug_mode) {
                std.debug.print("Transferred {} goroutines from P{} to global queue\n", .{ actual_count, p.getID() });
            }
        }

        /// Get the next goroutine to execute from a specific processor.
        /// Prioritizes runnext (fast path) over the main queue.
        /// Returns WorkItem with goroutine and source information.
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func runqget").
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
        pub fn runqget(self: *Self, p: *P) WorkItem {
            _ = self;

            // Fast path: check runnext first.
            if (p.getRunnext()) |g| {
                p.clearRunnext(); // Clear runnext, no active replenishment.
                return .{ .g = g, .src = .Runnext };
            }

            // Slow path: get from main queue
            const g = p.runq.dequeue();
            return .{ .g = g, .src = .Runq };
        }
    };
}
