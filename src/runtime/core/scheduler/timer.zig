const std = @import("std");
const tg = @import("../../tg.zig");

const G = tg.G;

/// Timer/preemption support for the scheduler.
/// Provides tick advancement, periodic preemption passes,
/// and a hook for injection at dispatch points.
pub fn bind(comptime Self: type) type {
    return struct {
        /// Advance the scheduler tick counter and
        /// run a preemption pass if the period has elapsed.
        pub fn onRoundTick(self: *Self) void {
            // increment global tick
            self.ticks += 1;
            // check and run periodic preemption
            self.maybePreemptPass();
        }

        /// Perform a periodic preemption pass.
        /// Marks each P's runnext goroutine for preemption
        /// if it has not been marked already.
        pub fn maybePreemptPass(self: *Self) void {
            // not yet reached the next trigger
            if (self.ticks < self.next_preempt_tick) return;

            // schedule next trigger
            self.next_preempt_tick += self.preempt_period;

            if (self.debug_mode) {
                std.debug.print(
                    "[preemptor] tick={} period={} → preempt pass\n",
                    .{ self.ticks, self.preempt_period },
                );
            }

            // iterate over all processors and mark one local candidate per P
            for (self.processors) |*p| {
                const g = p.previewLocalNext() orelse continue; // view-only

                if (!g.isPreemptRequested()) {
                    g.requestPreempt();

                    if (self.debug_mode) {
                        const src = if (p.hasRunnext()) "runnext" else "runq-front";
                        std.debug.print(
                            "[preemptor] mark G{} (P{} {s})\n",
                            .{ g.getID(), p.getID(), src },
                        );
                    }
                }
            }
        }

        /// Hook for dispatch-time injection of preemption.
        /// Currently disabled; returns false in this version.
        pub fn shouldInjectPreemptNow(self: *Self, g: *G) bool {
            _ = self;
            _ = g;
            return false;
        }
    };
}
