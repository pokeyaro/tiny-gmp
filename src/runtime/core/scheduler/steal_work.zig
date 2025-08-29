// =====================================================
// Steal Work (victim P's local runq → thief P's local runq)
// =====================================================

const std = @import("std");
const tg = @import("../../tg.zig");
const Types = @import("types.zig");

// Modules
const random = tg.lib.algo.random;

// Types
const P = tg.P;
const WorkItem = Types.WorkItem;

pub fn bind(comptime Self: type) type {
    return struct {
        /// How many full rounds of victim scanning to attempt.
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "const stealTries").
        const stealTries: usize = 4;

        /// Iterator state for victim selection.
        const StealIter = struct {
            start: usize,
            idx: usize,
            tries: usize,
        };

        /// Try to steal runnable goroutines for `thief` from other processors.
        /// Order: randomized victim scan → per-victim half-batch transfer → return one to run.
        /// On success, returns a WorkItem that can run immediately (its source remains `.Runq`).
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func stealWork").
        pub fn stealWork(self: *Self, thief: *P) ?WorkItem {
            const start = self.randStartIndex() orelse return null;

            var iter = StealIter{
                .start = start,
                .idx = 0,
                .tries = 0,
            };

            const budget = self.stealBudget();

            // Noise-control flags for summary logging.
            var printed_no_capacity = false;
            var saw_any_victim = false;
            var saw_any_nonempty = false;
            const n = self.processorCount();

            while (iter.tries < budget) : (iter.tries += 1) {
                const victim = self.chooseVictim(thief, &iter) orelse break;
                saw_any_victim = true;

                // If thief has no local capacity, print once and stop scanning.
                if (!thief.runq.hasCapacity()) {
                    if (self.debug_mode and !printed_no_capacity) {
                        std.debug.print(
                            "[steal] P{} skip: no capacity (size/cap = {}/{})\n",
                            .{ thief.getID(), thief.runq.size(), thief.runq.capacity() },
                        );
                    }
                    printed_no_capacity = true;
                    break;
                }

                // Skip empty victim silently (we'll summarize later).
                if (!victim.hasWork()) {
                    continue;
                }
                saw_any_nonempty = true;

                // Perform one steal attempt (we do NOT steal runnext on purpose).
                const taken = self.runqsteal(thief, victim);
                if (taken > 0) {
                    if (self.debug_mode) {
                        std.debug.print("[steal] P{} <- {} from P{}\n", .{ thief.getID(), taken, victim.getID() });
                    }

                    // Thief's local queue should now have work: dequeue one to run.
                    if (self.runqget(thief)) |wi| {
                        return wi;
                    }
                    // Unlikely case: took > 0 but dequeue failed; conservatively continue.
                }
                // If we reached here, either victim shrank during attempt or nothing moved;
                // keep scanning within budget.
            }

            // If we scanned a full round (or budget ended) and *every* victim we looked at was empty,
            // print a single summary line with the victim order.
            if (self.debug_mode and saw_any_victim and !saw_any_nonempty) {
                self.displayVictimScan(thief, start, n);
            }

            return null;
        }

        // === Private Helper Methods ===

        /// Randomized start index for victim scan.
        /// Returns null if there is <= 1 processor (no steal possible).
        fn randStartIndex(self: *const Self) ?usize {
            const n = self.processorCount();
            if (n <= 1) return null;
            return random.cheapRandIndex(n);
        }

        /// Total attempt budget = stealTries × number of processors.
        /// This limits how many victim scans we perform to avoid spinning forever.
        fn stealBudget(self: *const Self) usize {
            return self.processorCount() * stealTries;
        }

        /// Randomized start + ring scan, skipping `thief` itself.
        /// Returns null when we’ve enumerated one full round.
        fn chooseVictim(self: *const Self, thief: *P, iter: *StealIter) ?*P {
            const n = self.processorCount();
            if (n == 0 or iter.idx >= n) return null;

            while (iter.idx < n) {
                const pos = (iter.start + iter.idx) % n;
                iter.idx += 1; // Consume the current position (advance regardless of return/skip).

                const cand = &self.processors[pos];
                if (cand.getID() == thief.getID()) {
                    continue; // Skip self.
                }
                return cand; // Found a valid candidate.
            }

            return null; // Completed one full round.
        }

        /// Steal half of victim.runq into thief.runq.
        /// Returns the number of goroutines actually moved.
        /// Note: We intentionally diverge from Go by not stealing runnext.
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func runqsteal").
        fn runqsteal(self: *Self, thief: *P, victim: *P) usize {
            _ = self;

            const n = calcStealCount(thief, victim);
            if (n == 0) return 0;

            return moveBatch(thief, victim, n);
        }

        // === Pure Functions ===

        /// Calculate the number of goroutines to steal this round:
        /// floor(victim.size / 2), capped by thief’s remaining capacity.
        fn calcStealCount(thief: *const P, victim: *const P) usize {
            const victim_sz = victim.runq.size();
            if (victim_sz == 0) return 0;

            var half = victim_sz / 2; // floor division
            if (half == 0) return 0;

            const available = thief.runq.available();
            if (available == 0) return 0;

            if (half > available) half = available;
            return half;
        }

        /// Move up to `n` goroutines from victim.runq to thief.runq (in queue order).
        /// Returns the number of goroutines actually moved.
        fn moveBatch(thief: *P, victim: *P, n: usize) usize {
            var moved: usize = 0;

            while (moved < n and thief.runq.hasCapacity()) : (moved += 1) {
                const gp = victim.runq.dequeue() orelse break;
                const ok = thief.runq.enqueue(gp);
                if (!ok) break; // Shouldn't happen if hasCapacity() was true, but stay defensive.
            }

            return moved;
        }
    };
}
