// =====================================================
// Timer & Preemption Timeline
// =====================================================

const std = @import("std");
const tg = @import("../../tg.zig");
const Types = @import("types.zig");

// Types
const G = tg.G;
const TimerEntry = Types.TimerEntry;

/// Timer/preemption support for the scheduler.
/// Provides tick advancement, periodic preemption passes,
/// and a hook for injection at dispatch points.
pub fn bind(comptime Self: type) type {
    return struct {
        // === Round entry hook ===

        /// Called at the beginning of each scheduling round:
        ///   1) advance the global tick
        ///   2) process expired timers (move back to global runq and wake one P)
        ///   3) maybe run a periodic preemption marking pass
        pub fn onRoundTick(self: *Self) void {
            self.ticks += 1; // advance timebase
            self.processExpiredTimers(); // unpark ready goroutines
            self.maybePreemptPass(); // periodic, view-only marking
        }

        // === Public timer helpers ===

        /// Park a goroutine into the timer list for `delay_ticks` ticks.
        /// When the deadline is reached, it will be moved back to the global runq.
        pub fn timerPark(self: *Self, g: *G, delay_ticks: u32) void {
            const entry = TimerEntry{
                .g = g,
                .deadline = self.ticks + delay_ticks,
            };
            self.timers.append(self.allocator, entry) catch @panic("timerPark: OOM");

            if (self.debug_mode) {
                std.debug.print(
                    "[timer] park G{} until tick {} (+{})\n",
                    .{ g.getID(), entry.deadline, delay_ticks },
                );
            }
        }

        /// Demo utility: take up to `n` goroutines from the global queue
        /// and park them for `delay_ticks`. Helps visualize timer wakeups.
        pub fn demoParkSome(self: *Self, n: usize, delay_ticks: u32) void {
            var took: usize = 0;
            while (took < n) : (took += 1) {
                if (self.runq.dequeue()) |g| {
                    self.timerPark(g, delay_ticks);
                } else break;
            }
            if (self.debug_mode) {
                std.debug.print("[timer] demo parked {} goroutine(s)\n", .{took});
            }
        }

        /// Dispatch-time injection hook.
        /// Reserved for future use; currently disabled.
        pub fn shouldInjectPreemptNow(self: *Self, g: *G) bool {
            _ = self;
            _ = g;
            return false;
        }

        // === Private helpers ===

        /// Scan `timers` and move all entries whose `deadline` ≤ `ticks`
        /// back to the global run queue; wake one idle P per entry.
        /// Uses swap-remove to keep O(1) removal (order not preserved).
        fn processExpiredTimers(self: *Self) void {
            var i: usize = 0;
            while (i < self.timers.items.len) {
                const t = self.timers.items[i];

                if (t.deadline > self.ticks) {
                    i += 1; // not yet due
                    continue;
                }

                if (self.debug_mode) {
                    std.debug.print("[timer] unpark G{} at tick {}\n", .{ t.g.getID(), self.ticks });
                }

                // Move back to global queue and try to wake one idle P.
                self.globrunqput(t.g);
                _ = self.tryWake(1);

                // swap-remove: put last item into i, then pop the tail
                const last = self.timers.items.len - 1;
                self.timers.items[i] = self.timers.items[last];
                _ = self.timers.pop();
                // do not increment i here; re-check the swapped-in entry
            }
        }

        /// Periodic preemption marking:
        /// every `preempt_period` ticks, peek each P’s next local candidate
        /// (runnext or runq-front) and mark it `preempt` if not already marked.
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

            // iterate over all processors and mark the read-only next candidate
            for (self.processors) |*p| {
                const g = p.previewLocalNext() orelse continue; // read-only peek

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
    };
}
