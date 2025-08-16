// =====================================================
// Goroutine Runner (execute & finalize)
// =====================================================

const std = @import("std");
const tg = @import("../../tg.zig");

// Modules
const executor = tg.executor;
const lifecycle = tg.lifecycle;

// Types
const G = tg.G;
const P = tg.P;

pub fn bind(comptime Self: type) type {
    return struct {
        /// Execute one goroutine on a processor and handle completion/yield.
        pub fn executeGoroutine(self: *Self, p: *P, g: *G) void {
            // Mark the processor as running for this dispatch.
            p.setStatus(.Running);

            // Execute one timeslice of the goroutine's task.
            const done = executor.execute(g);

            if (self.debug_mode) {
                if (done) {
                    std.debug.print("P{}: G{} done\n", .{ p.getID(), g.getID() });
                } else {
                    std.debug.print("[yield] P{}: G{} slice used, remaining {}/{}\n", .{ p.getID(), g.getID(), g.stepsLeft(), g.stepsTotal() });
                }
            }

            if (done) {
                // Task completed — clean up the goroutine.
                lifecycle.destroyproc(self, g);
            } else {
                // yield/preempt → tail only.
                self.runqput(p, g, false);
            }

            // Update processor status after execution.
            p.syncStatus();
        }
    };
}
