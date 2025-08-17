// =====================================================
// Scheduler Construction / Destruction
// =====================================================

const std = @import("std");
const tg = @import("../../tg.zig");

// Modules
const scheduler_config = tg.config.scheduler;

// Types
const P = tg.P;
const lifecycle = tg.lifecycle;
const GlobalQueue = tg.queue.global_queue.GlobalQueue;

pub fn bind(comptime Self: type) type {
    return struct {
        /// Create processors array with sequential IDs.
        fn createProcessors(allocator: std.mem.Allocator, count: u32) ![]P {
            const processors = try allocator.alloc(P, count);
            for (processors, 0..) |*p, i| {
                p.* = P.init(@as(u32, @intCast(i))); // P0, P1, P2, P3...
            }
            return processors;
        }

        /// Initialize the global scheduler.
        pub fn init(allocator: std.mem.Allocator, debug_mode: bool) !Self {
            const nproc = scheduler_config.getProcessorCount();
            const processors = try createProcessors(allocator, nproc);

            return .{
                .runq = GlobalQueue.init(),
                .processors = processors,
                .nproc = nproc,
                .pidle = null,
                .allocator = allocator,
                .debug_mode = debug_mode,
            };
        }

        /// Clean up scheduler resources.
        pub fn deinit(self: *Self) void {
            // Clean up global queue.
            while (self.runq.dequeue()) |g| {
                lifecycle.destroyproc(self, g);
            }

            // Clean up processor queues.
            for (self.processors) |*p| {
                if (p.runnext) |g| {
                    lifecycle.destroyproc(self, g);
                }
                while (p.runq.dequeue()) |g| {
                    lifecycle.destroyproc(self, g);
                }
            }

            // Original cleanup.
            self.runq.deinit();
            self.allocator.free(self.processors);
        }
    };
}
