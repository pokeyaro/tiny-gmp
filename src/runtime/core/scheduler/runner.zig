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
        /// Run a goroutine on a processor and handle cleanup/state updates.
        pub fn executeGoroutine(self: *Self, p: *P, g: *G) void {
            // Mark P running for this dispatch.
            p.setStatus(.Running);

            // Execute the goroutine's task.
            executor.execute(g);

            if (self.debug_mode) {
                std.debug.print("P{}: G{} done\n", .{ p.getID(), g.getID() });
            }

            // Clean up the goroutine after execution.
            lifecycle.destroyproc(self, g);

            // Update processor status.
            p.syncStatus();
        }
    };
}
