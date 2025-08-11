const std = @import("std");
const tg = @import("../../tg.zig");

// Types
const P = tg.P;

// =====================================================
// Idle-P Operations
// =====================================================

pub fn bind(comptime Self: type) type {
    return struct {
        /// Put P onto the idle stack (LIFO).
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func pidleput").
        pub fn pidleput(self: *Self, p: *P) void {
            // Debug assertion: idle P should not have any remaining local work
            if (std.debug.runtime_safety) {
                if (p.hasWork()) @panic("pidleput: P has non-empty run queue/runnext");
            }

            // LIFO push
            p.link = self.pidle;
            self.pidle = p;
            _ = self.npidle.fetchAdd(1, .seq_cst);

            if (self.debug_mode) {
                std.debug.print("[pidle] +P{} (idle={})\n", .{ p.getID(), self.getIdleCount() });
            }
        }

        /// Get one P from the idle stack (or null if none).
        ///
        /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func pidleget").
        pub fn pidleget(self: *Self) ?*P {
            const p = self.pidle orelse return null;

            // LIFO pop
            self.pidle = p.link;
            p.link = null;
            _ = self.npidle.fetchSub(1, .seq_cst);

            if (self.debug_mode) {
                std.debug.print("[pidle] -P{} (idle={})\n", .{ p.getID(), self.getIdleCount() });
            }
            return p;
        }

        /// Check if idle stack is empty
        pub fn pidleEmpty(self: *const Self) bool {
            return self.pidle == null;
        }
    };
}
