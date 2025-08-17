// =====================================================
// Basic Scheduler Operations
// =====================================================

pub fn bind(comptime Self: type) type {
    return struct {
        /// Generate next unique goroutine ID (thread-safe).
        pub fn nextGID(self: *Self) u64 {
            return self.goidgen.fetchAdd(1, .seq_cst);
        }

        /// Check if global queue is empty.
        pub fn isEmpty(self: *const Self) bool {
            return self.runq.isEmpty();
        }

        /// Get the number of goroutines in global queue.
        pub fn runqsize(self: *const Self) usize {
            return self.runq.size();
        }

        /// Get the total number of processors in the scheduler.
        pub fn processorCount(self: *const Self) u32 {
            return self.nproc;
        }

        /// Get current idle processor count.
        pub fn getIdleCount(self: *const Self) u32 {
            return self.npidle.load(.seq_cst);
        }

        /// Check if there are any idle processors available.
        pub fn hasIdleProcessors(self: *const Self) bool {
            return self.npidle.load(.seq_cst) > 0;
        }
    };
}
