// =====================================================
// Parking / Wakeup (pidle) Operations
// =====================================================

const std = @import("std");
const tg = @import("../../tg.zig");

// Types
const P = tg.P;

pub fn bind(comptime Self: type) type {
    return struct {
        // === Public High-Level APIs ===

        /// Park this processor on the pidle stack if it has no runnable work.
        pub fn parkIfNoWork(self: *Self, p: *P) void {
            if (!p.hasWork() and !p.isParked()) {
                self.pidleput(p);
            }
        }

        /// Park all processors that currently have no runnable work.
        pub fn parkAllIfNoWork(self: *Self, processors: []P) void {
            for (processors) |*p| {
                self.parkIfNoWork(p);
            }
        }

        /// Try to wake N idle processors.
        /// Returns the actual number of processors woken up.
        pub fn tryWake(self: *Self, n: u32) u32 {
            if (n == 0) return 0;

            var woken: u32 = 0;
            var remaining = n;

            while (remaining > 0 and !self.pidleEmpty()) {
                if (self.pidleget()) |p| {
                    if (self.debug_mode) {
                        std.debug.print("[wake] Woke P{}\n", .{p.getID()});
                    }

                    // TODO: Actually assign work to this P in later steps
                    // For now, just count it as woken

                    woken += 1;
                    remaining -= 1;
                } else {
                    break; // No more idle processors.
                }
            }

            if (self.debug_mode and woken > 0) {
                std.debug.print("[wake] Woke {} processor(s), {} idle remaining\n", .{ woken, self.getIdleCount() });
            }

            return woken;
        }

        /// Wake one idle processor.
        /// Pops from the pidle stack (LIFO) and marks it Running. Returns true if woken.
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func wakep").
        pub fn wakep(self: *Self) bool {
            return self.tryWake(1) > 0;
        }

        // === Core Idle Stack Operations ===

        /// Put P onto the idle stack (LIFO).
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func pidleput").
        pub fn pidleput(self: *Self, p: *P) void {
            // Debug assertion: idle P should not have any remaining local work.
            if (std.debug.runtime_safety) {
                if (p.hasWork()) @panic("pidleput: P has non-empty run queue/runnext");
            }

            // Mark P as Parked before pushing onto pidle (about to sleep).
            p.setStatus(.Parked);

            // LIFO push.
            p.linkTo(self.getIdleHead());
            self.setIdleHead(p);
            self.incrementIdleCount();

            if (self.debug_mode) {
                std.debug.print("[pidle] +P{} (idle={})\n", .{ p.getID(), self.getIdleCount() });
            }
        }

        /// Get one P from the idle stack (or null if none).
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func pidleget").
        pub fn pidleget(self: *Self) ?*P {
            const p = self.getIdleHead() orelse return null;

            // LIFO pop.
            self.setIdleHead(p.link);
            p.clearLink();
            self.decrementIdleCount();

            // Mark P as Running after popping from pidle (wake up).
            p.setStatus(.Running);

            if (self.debug_mode) {
                std.debug.print("[pidle] -P{} (idle={})\n", .{ p.getID(), self.getIdleCount() });
            }
            return p;
        }

        /// Check if idle stack is empty.
        pub fn pidleEmpty(self: *const Self) bool {
            return self.pidle == null;
        }

        // === Private Helper Methods ===

        /// Increment idle processor count.
        fn incrementIdleCount(self: *Self) void {
            _ = self.npidle.fetchAdd(1, .seq_cst);
        }

        /// Decrement idle processor count.
        fn decrementIdleCount(self: *Self) void {
            _ = self.npidle.fetchSub(1, .seq_cst);
        }

        /// Set the head of idle processor stack.
        fn setIdleHead(self: *Self, p: ?*P) void {
            self.pidle = p;
        }

        /// Get the current head of idle processor stack.
        fn getIdleHead(self: *const Self) ?*P {
            return self.pidle;
        }
    };
}
