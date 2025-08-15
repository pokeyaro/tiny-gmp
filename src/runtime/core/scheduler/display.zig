// =====================================================
// Scheduler Display & Debug Utilities
// =====================================================

const std = @import("std");
const tg = @import("../../tg.zig");

// Types
const P = tg.P;

pub fn bind(comptime Self: type) type {
    return struct {
        /// Print a scheduler snapshot with a custom title (debug mode only).
        pub fn displaySnapshot(self: *const Self, title: []const u8) void {
            if (!self.debug_mode) return;

            std.debug.print("\n=== {s} ===\n", .{title});

            const proc_count = self.processorCount();
            const idle_count = self.getIdleCount();
            const g_count = self.runq.size();

            std.debug.print("Processors: {}, Idle: {}\n", .{ proc_count, idle_count });
            std.debug.print("Global runq size: {}\n", .{g_count});
            if (g_count > 0) {
                self.runq.display();
            }

            for (self.processors) |*p| {
                p.display();
            }
        }

        /// Backward-compat snapshot (debug only).
        pub fn display(self: *const Self) void {
            self.displaySnapshot("Scheduler Status");
        }

        /// Final summary (debug only): snapshot + idle summary + pidle stack.
        pub fn displayFinalStatus(self: *const Self) void {
            if (!self.debug_mode) return;

            self.displaySnapshot("Final Status");
            std.debug.print("Idle processors: [{}/{}]\n", .{ self.getIdleCount(), self.processorCount() });
            self.displayPidle();
        }

        /// Show the pidle stack (debug only), e.g.:
        /// Example: "Pidle stack: P4(head) -> P3 -> P2" or "(empty)".
        pub fn displayPidle(self: *const Self) void {
            if (!self.debug_mode) return;

            std.debug.print("Pidle stack: ", .{});

            var node = self.pidle; // head of idle P linked list
            if (node == null) {
                std.debug.print("(empty)\n", .{});
                return;
            }

            var first = true;
            while (node) |p| {
                if (!first) std.debug.print(" -> ", .{});
                if (first) {
                    std.debug.print("P{}(head)", .{p.getID()});
                    first = false;
                } else {
                    std.debug.print("P{}", .{p.getID()});
                }
                node = p.link;
            }
            std.debug.print("\n", .{});
        }

        /// Print the victim scan order for a steal attempt.
        /// Example: "[steal] P0 scan(start=3): P3 -> P4 -> P0(skip) -> P1 -> P2 (all empty)".
        pub fn displayVictimScan(self: *const Self, thief: *const P, start: usize, n: usize) void {
            if (!self.debug_mode or n == 0) return;

            std.debug.print("[steal] P{} scan(start={}): ", .{ thief.getID(), start });

            var i: usize = 0;
            var first = true;
            while (i < n) : (i += 1) {
                const pos = (start + i) % n;
                const p = &self.processors[pos];

                if (!first) std.debug.print(" -> ", .{});
                first = false;

                if (p.getID() == thief.getID()) {
                    std.debug.print("P{}(skip)", .{p.getID()});
                } else {
                    std.debug.print("P{}", .{p.getID()});
                }
            }

            std.debug.print(" (all empty)\n", .{});
        }
    };
}
