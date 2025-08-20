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

            // dispatch-time injection hook.
            if (self.shouldInjectPreemptNow(g)) {
                g.requestPreempt();
            }

            // Execute one scheduling slice.
            const done = executor.execute(g);

            if (self.debug_mode and done) {
                std.debug.print("P{}: G{} done\n", .{ p.getID(), g.getID() });
            }

            if (done) {
                // Task completed — clean up the goroutine.
                lifecycle.destroyproc(self, g);
            } else {
                // yield/preempt — tail only, with explicit reason recorded.
                self.runqputTailWithReason(p, g, g.getLastYieldReason());
            }

            // Update processor status after execution.
            p.syncStatus();
        }
    };
}
