// =====================================================
// Work Finder (runnext → local runq → global runq)
// =====================================================

const std = @import("std");
const tg = @import("../../tg.zig");

// Types
const P = tg.P;

pub fn bind(comptime Self: type, comptime WorkItem: type) type {
    return struct {
        /// Provides a method to locate the next runnable goroutine for a given processor.
        /// Search order: runnext (local) → runq (local) → global queue.
        /// Returns a WorkItem describing the goroutine and its source.
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func findRunnable").
        pub fn findrunnable(self: *Self, p: *P) WorkItem {
            // 1. Fast path: Try to get work from processor's local queue first.
            const wi: WorkItem = self.runqget(p);
            if (wi.g != null) {
                return wi; // .Runnext or .Runq.
            }

            // 2. Slow path: pull a small batch from the global queue into the local run queue, then immediately return one to run.
            const qs_before = self.runqsize();
            if (self.globrunqget(p, 0)) |g| {
                return .{ .g = g, .src = .Global };
            }

            if (self.debug_mode and qs_before > 0) {
                const available = p.runq.capacity() - p.runq.size();
                if (available == 0) {
                    std.debug.print("[global] P{} skipped: local queue full\n", .{p.getID()});
                } else {
                    std.debug.print("[global] P{} <- batch empty\n", .{p.getID()});
                }
            }

            // 3. No work found.
            return .{ .g = null, .src = .None };
        }

        /// Finds a runnable goroutine and executes it immediately.
        /// Returns true if a goroutine was found and executed.
        pub fn tryRunFromFinder(self: *Self, p: *P) bool {
            const wi: WorkItem = self.findrunnable(p);
            if (wi.g) |g| {
                if (self.debug_mode) {
                    std.debug.print("P{}: Executing G{} (from {s})\n", .{ p.getID(), g.getID(), wi.src.toString() });
                }
                self.executeGoroutine(p, g);
                return true;
            }
            return false;
        }
    };
}
