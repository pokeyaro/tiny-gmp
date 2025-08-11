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
            // Debug assertion: idle P should not have any remaining local work.
            if (std.debug.runtime_safety) {
                if (p.hasWork()) @panic("pidleput: P has non-empty run queue/runnext");
            }

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

            if (self.debug_mode) {
                std.debug.print("[pidle] -P{} (idle={})\n", .{ p.getID(), self.getIdleCount() });
            }
            return p;
        }

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

        /// Check if idle stack is empty.
        pub fn pidleEmpty(self: *const Self) bool {
            return self.pidle == null;
        }
    };
}
