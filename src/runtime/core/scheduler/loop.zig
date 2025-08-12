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
        /// Main scheduling loop - drives the entire scheduler.
        /// Continuously looks for work and executes goroutines until no work remains.
        pub fn schedule(self: *Self) void {
            if (self.debug_mode) {
                std.debug.print("=== Scheduler starting with {} processors ===\n", .{self.nproc});
            }

            var round: u32 = 1;

            while (hasWork(self)) {
                if (self.debug_mode) {
                    std.debug.print("\n--- Round {} ---\n", .{round});
                }

                var work_done = false;

                // Try to schedule on each processor.
                for (self.processors) |*p| {
                    if (scheduleOnProcessor(self, p)) {
                        work_done = true;
                    }
                }

                // If no work was done this round, break to avoid infinite loop.
                if (!work_done) {
                    if (self.debug_mode) {
                        std.debug.print("No work found, scheduler stopping\n", .{});
                    }
                    break;
                }

                round += 1;
            }

            if (self.debug_mode) {
                std.debug.print("\nScheduler: All processors idle, scheduling finished\n", .{});

                // Display final status.
                std.debug.print("\n=== Final Status ===\n", .{});
                for (self.processors) |*p| {
                    std.debug.print("P{}: {} tasks remaining\n", .{ p.getID(), p.totalGoroutines() });
                }
            }

            // Mark all processors without work as idle.
            self.markIdleBatch(self.processors);

            if (self.debug_mode) {
                std.debug.print("\n=== Idle Processor Management ===\n", .{});
                std.debug.print("Total idle processors: {}\n", .{self.getIdleCount()});
                std.debug.print("Idle stack empty: {}\n", .{self.pidleEmpty()});
            }
        }

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
            // Try to get work from processor's local queue first.
            const work: WorkItem = self.runqget(p);

            if (work.g) |g| {
                logExecStart(self, p, g, work.src);

                // Execute the goroutine.
                executeGoroutine(self, p, g);

                return true;
            }

            // No local work, try to get from global queue.
            if (!self.runq.isEmpty()) {
                if (self.globrunqget(p, 0)) |g| { // 0 == no extra cap
                    logExecStart(self, p, g, .Global);

                    // Execute the goroutine.
                    executeGoroutine(self, p, g);

                    return true;
                } else if (self.debug_mode) {
                    std.debug.print("[global] P{} <- batch empty\n", .{p.getID()});
                }
            }

            // No work found for this processor.
            if (self.debug_mode) {
                std.debug.print("[idle]  P{} no work\n", .{p.getID()});
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
