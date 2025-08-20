// =====================================================
// Main Scheduling Loop
// =====================================================

const std = @import("std");
const tg = @import("../../tg.zig");

// Types
const P = tg.P;

pub fn bind(comptime Self: type) type {
    return struct {
        /// Main scheduling loop — orchestrates processor execution.
        /// Continuously searches for runnable goroutines and dispatches them until no work remains.
        pub fn schedule(self: *Self) void {
            self.main_started = true;
            defer self.main_started = false;

            if (self.debug_mode) {
                std.debug.print("=== Scheduler starting with {} processors ===\n", .{self.processorCount()});
            }

            var round: u32 = 1;

            while (true) {
                // advance the scheduler timeline and maybe run a preemption pass
                self.onRoundTick();

                // Early exit: no global work and all P are parked on pidle.
                if (self.allPIdleAndRunqEmpty()) {
                    if (self.debug_mode) {
                        std.debug.print("All processors idle and no work, scheduler stopping\n", .{});
                    }
                    break;
                }

                if (self.debug_mode) {
                    std.debug.print("\n--- Round {} ---\n", .{round});
                }

                // Iterate all processors.
                for (self.processors) |*p| {
                    switch (p.status) {
                        // PARKED: already on pidle stack — nothing to do this round.
                        .Parked => {
                            if (self.debug_mode) {
                                std.debug.print("[sleep] P{} on pidle\n", .{p.getID()});
                            }
                            continue;
                        },

                        // IDLE: no local work; try once via unified finder, else park.
                        .Idle => {
                            if (!self.tryRunFromFinder(p)) {
                                self.pidleput(p); // park once
                            }
                        },

                        // RUNNING: aggressively seek work via unified path; else park.
                        .Running => {
                            if (!self.scheduleOnP(p)) {
                                self.pidleput(p); // no work -> park
                            }
                        },
                    }
                }

                round += 1;
            }

            // Use the unified display helper (debug-only inside).
            self.displayFinalStatus();
        }

        // === Private Helper Methods ===

        /// Returns true if the scheduler has no runnable work remaining.
        fn allPIdleAndRunqEmpty(self: *const Self) bool {
            return self.runq.isEmpty() and self.getIdleCount() >= self.processorCount();
        }

        /// Try to schedule work on a specific processor.
        /// Returns true if work was done, false if no work available.
        fn scheduleOnP(self: *Self, p: *P) bool {
            // First attempt: try to find and execute a runnable goroutine
            // from local queues or the global queue.
            if (self.tryRunFromFinder(p)) return true;

            // Second attempt: if other processors are still running,
            // try again in case they have published new work.
            if (self.anyOtherPHasWork(p) and self.tryRunFromFinder(p)) return true;

            // No work found: log idle state (debug mode only).
            if (self.debug_mode) {
                std.debug.print("[idle]  P{} no work\n", .{p.getID()});
            }

            return false;
        }

        /// Check if any other processors are still working.
        /// This indicates that new work might be added to global queue soon.
        fn anyOtherPHasWork(self: *const Self, current_p: *const P) bool {
            for (self.processors) |*p| {
                if (p.getID() != current_p.getID() and p.hasWork()) {
                    return true;
                }
            }

            return false;
        }
    };
}
