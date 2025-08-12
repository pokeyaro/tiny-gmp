const std = @import("std");
const tg = @import("../../tg.zig");

// Modules
const executor = tg.executor;
const lifecycle = tg.lifecycle;

// Types
const G = tg.G;
const P = tg.P;

// =====================================================
// Main Scheduling Loop
// =====================================================

pub fn bind(comptime Self: type, comptime WorkItem: type, comptime GSrc: type) type {
    return struct {
        /// Main scheduling loop — orchestrates processor execution.
        /// Continuously searches for runnable goroutines and dispatches them until no work remains.
        pub fn schedule(self: *Self) void {
            self.main_started = true;
            defer self.main_started = false;

            if (self.debug_mode) {
                std.debug.print("=== Scheduler starting with {} processors ===\n", .{self.nproc});
            }

            var round: u32 = 1;

            while (true) {
                // Early exit: no global work and all P are parked on pidle.
                if (self.runq.isEmpty() and self.getIdleCount() >= self.nproc) {
                    if (self.debug_mode) {
                        std.debug.print("All processors idle and no work, scheduler stopping\n", .{});
                    }
                    break;
                }

                if (self.debug_mode) {
                    std.debug.print("\n--- Round {} ---\n", .{round});
                }

                var work_done = false;

                // Iterate all processors.
                for (self.processors) |*p| {
                    // Truly sleeping Ps (already on pidle stack) do nothing this round.
                    if (p.isOnIdleStack()) {
                        if (self.debug_mode) {
                            std.debug.print("[sleep] P{} on pidle\n", .{p.getID()});
                        }
                        continue;
                    }

                    // P reports idle (no local work + status Idle): try global once, then park.
                    if (p.isIdle()) {
                        if (self.tryGetFromGlobal(p)) {
                            work_done = true;
                            continue;
                        }
                        if (!p.isOnIdleStack()) {
                            self.pidleput(p); // single entry to pidle.
                        }
                        continue;
                    }

                    // Active P: try local, then global (inside scheduleOnProcessor).
                    if (scheduleOnProcessor(self, p)) {
                        work_done = true;
                    } else {
                        // No work now → park once.
                        if (!p.isOnIdleStack()) {
                            self.pidleput(p);
                        }
                    }
                }

                round += 1;
            }

            if (self.debug_mode) {
                std.debug.print("\n=== Final Status ===\n", .{});
                for (self.processors) |*p| {
                    std.debug.print("P{}: {} tasks remaining\n", .{ p.getID(), p.totalGoroutines() });
                }
                std.debug.print("Idle processors: [{}/{}]\n", .{ self.getIdleCount(), self.processorCount() });
                self.displayPidle();
            }
        }

        // === Private Helper Methods ===

        /// Check if there's any work to do across all processors and global queue.
        fn hasWork(self: *const Self) bool {
            // Check if global queue has work.
            if (!self.runq.isEmpty()) return true;

            // Check if any processor has work.
            for (self.processors) |*p| {
                if (p.hasWork()) {
                    return true;
                }
            }

            return false;
        }

        /// Try to schedule work on a specific processor.
        /// Returns true if work was done, false if no work available.
        ///
        /// Note: Similar to Go's findRunnable() but simplified for single processor.
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func findRunnable").
        fn scheduleOnProcessor(self: *Self, p: *P) bool {
            // Fast path: Try to get work from processor's local queue first.
            if (self.tryGetFromLocal(p)) {
                return true;
            }

            // Slow path: Try global queue
            if (self.tryGetFromGlobal(p)) {
                return true;
            }

            // More aggressive work seeking before giving up.
            // If there are still running processors, they might add work soon.
            if (self.hasOtherProcessorsWorking(p)) {
                // Give other processors a chance to add work to global queue.
                if (self.tryGetFromGlobal(p)) {
                    return true;
                }
            }

            // No work found for this processor.
            if (self.debug_mode) {
                std.debug.print("[idle]  P{} no work\n", .{p.getID()});
            }

            return false;
        }

        /// Try to get work from local queue and execute if found.
        fn tryGetFromLocal(self: *Self, p: *P) bool {
            const work: WorkItem = self.runqget(p);

            if (work.g) |g| {
                logExecStart(self, p, g, work.src);
                executeGoroutine(self, p, g);
                return true;
            }

            return false;
        }

        /// Try to get work from global queue and execute if found.
        fn tryGetFromGlobal(self: *Self, p: *P) bool {
            if (self.runq.isEmpty()) return false;

            if (self.globrunqget(p, 0)) |g| {
                logExecStart(self, p, g, .Global);
                executeGoroutine(self, p, g);
                return true;
            }

            if (self.debug_mode) {
                std.debug.print("[global] P{} <- batch empty\n", .{p.getID()});
            }
            return false;
        }

        /// Check if any other processors are still working.
        /// This indicates that new work might be added to global queue soon.
        fn hasOtherProcessorsWorking(self: *const Self, current_p: *const P) bool {
            for (self.processors) |*p| {
                if (p.getID() != current_p.getID() and p.hasWork()) {
                    return true;
                }
            }
            return false;
        }

        /// Execute a goroutine on a specific processor.
        fn executeGoroutine(self: *Self, p: *P, g: *G) void {
            // Set processor status.
            p.setStatus(.Running);

            // Execute the goroutine with context.
            executor.execute(g);

            if (self.debug_mode) {
                std.debug.print("P{}: G{} done\n", .{ p.getID(), g.getID() });
            }

            // Clean up the goroutine after execution.
            lifecycle.destroyproc(self, g);

            // Update processor status.
            p.syncStatus();
        }

        /// Debug-only helper to print a unified "start executing" line with source.
        fn logExecStart(self: *Self, p: *P, g: *G, src: GSrc) void {
            if (!self.debug_mode) return;
            std.debug.print("P{}: Executing G{} (from {s})\n", .{ p.getID(), g.getID(), src.toString() });
        }
    };
}
