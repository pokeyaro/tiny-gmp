const std = @import("std");

// =====================================================
// Basic Scheduler Operations
// =====================================================

pub fn bind(comptime Self: type) type {
    return struct {
        /// Generate next unique goroutine ID (thread-safe).
        pub fn nextGID(self: *Self) u32 {
            return self.goidgen.fetchAdd(1, .seq_cst) + 1;
        }

        /// Check if global queue is empty.
        pub fn isEmpty(self: *const Self) bool {
            return self.runq.isEmpty();
        }

        /// Get the number of goroutines in global queue.
        pub fn runqsize(self: *const Self) usize {
            return self.runq.size();
        }

        /// Get current idle processor count.
        pub fn getIdleCount(self: *const Self) u32 {
            return self.npidle.load(.seq_cst);
        }

        /// Check if there are any idle processors available.
        pub fn hasIdleProcessors(self: *const Self) bool {
            return self.npidle.load(.seq_cst) > 0;
        }

        /// Display scheduler state for debugging.
        pub fn display(self: *const Self) void {
            const idle_count = self.getIdleCount();
            std.debug.print("=== Scheduler Status ===\n", .{});
            std.debug.print("Processors: {}, Idle: {}\n", .{ self.nproc, idle_count });
            std.debug.print("Global goroutines: {}\n", .{self.runq.size()});
            self.runq.display();

            for (self.processors, 0..) |*p, i| {
                std.debug.print("P{}: ", .{i});
                p.display();
            }
        }
    };
}
