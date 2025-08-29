// =====================================================
// Work Finder (runnext → local runq → global runq)
// =====================================================

const std = @import("std");
const tg = @import("../../tg.zig");
const Types = @import("types.zig");

// Types
const P = tg.P;
const WorkItem = Types.WorkItem;

pub fn bind(comptime Self: type) type {
    return struct {
        /// Provides a method to locate the next runnable goroutine for a given processor.
        /// Search order: runnext (local) → runq (local) → global queue → stealing.
        /// Returns a WorkItem describing the goroutine and its source.
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func findRunnable").
        pub fn findRunnable(self: *Self, p: *P) ?WorkItem {
            // Fast path: local runnext → local runq.
            if (self.runqget(p)) |wi| return wi;

            // Slow path: try global queue (batch intake into local; return immediate one).
            const qs_before: usize = if (self.debug_mode) self.runqsize() else 0;
            if (self.globrunqgetWorkItem(p)) |wi| return wi;
            self.debugGlobalMiss(p, qs_before);

            // Steal path: try stealing a half-batch from another P into the local run queue, then dequeue one from local to run.
            if (self.stealWork(p)) |wi| return wi;

            // No work anywhere.
            return null;
        }

        /// Finds a runnable goroutine and executes it immediately.
        /// Returns true if a goroutine was found and executed.
        pub fn tryRunFromFinder(self: *Self, p: *P) bool {
            if (self.findRunnable(p)) |wi| {
                if (self.debug_mode) {
                    std.debug.print(
                        "P{}: Executing G{} (from {s})\n",
                        .{ p.getID(), wi.g.getID(), wi.sourceName() },
                    );
                }
                self.executeGoroutine(p, wi.g);
                return true;
            }
            return false;
        }

        // === Private Helper Methods ===

        fn debugGlobalMiss(self: *const Self, p: *const P, qs_before: usize) void {
            if (!self.debug_mode or qs_before == 0) return;

            if (p.runq.hasCapacity()) {
                std.debug.print("[global] P{} <- batch empty\n", .{p.getID()});
            } else {
                std.debug.print("[global] P{} skipped: local queue full\n", .{p.getID()});
            }
        }
    };
}
