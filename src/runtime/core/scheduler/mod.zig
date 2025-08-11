//! Production scheduler implementation
//!
//! Core GMP (Goroutine-Machine-Processor) scheduling algorithms implementing Go's
//! runtime scheduler. Features work-stealing, load balancing, and batch processing
//! with comprehensive debug support and performance monitoring capabilities.

const std = @import("std");
const goroutine = @import("../../gmp/goroutine.zig");
const processor = @import("../../gmp/processor.zig");
const local_queue = @import("../../queue/local_queue.zig");
const global_queue = @import("../../queue/global_queue.zig");
const scheduler_config = @import("../../config/scheduler_config.zig");
const shuffle = @import("../../../lib/algo/shuffle.zig");

// Import types
const G = goroutine.G;
const P = processor.P;
const GlobalQueue = global_queue.GlobalQueue;
const SchedulerConfig = scheduler_config.SchedulerConfig;

/// Source of a goroutine when it gets selected to run.
pub const GSrc = enum {
    Runnext,
    Runq,
    Global,

    /// Convert a GSrc enum to a human-readable string.
    pub fn toString(self: GSrc) []const u8 {
        return switch (self) {
            .Runnext => "runnext",
            .Runq => "runq",
            .Global => "global",
        };
    }
};

/// Result type returned by runqget function.
/// Contains the goroutine and information about its source.
pub const WorkItem = struct {
    g: ?*G,
    src: GSrc,

    /// Typed source accessor.
    pub fn source(self: WorkItem) GSrc {
        return self.src;
    }

    /// Human-readable source label.
    pub fn sourceName(self: WorkItem) []const u8 {
        return self.src.toString();
    }
};

// =====================================================
// Scheduler Implementation
// =====================================================

/// Global scheduler state, matching Go's schedt structure.
///
/// Go source: https://github.com/golang/go/blob/master/src/runtime/runtime2.go (search for "type schedt struct").
pub const schedt = struct {
    const Self = @This();

    // =====================================================
    // Core Scheduler Data Structure
    // =====================================================

    // ==== Core Scheduling Fields ====

    /// Global runnable queue (corresponds to Go's runq gQueue).
    runq: GlobalQueue,

    /// Array of processors, each P manages local goroutine scheduling.
    /// Corresponds to Go's allp []*p array (all processors, active + idle).
    /// Go also uses separate pidle linked list for idle P management.
    processors: []P,

    /// Number of processors (corresponds to Go's gomaxprocs).
    /// Fixed at initialization, matching CPU core count.
    nproc: u32,

    // ==== Statistics and State Fields ====

    /// Head of idle processor linked list (corresponds to Go's pidle).
    /// Uses intrusive linked list via P.link
    pidle: ?*P = null,

    /// Number of idle processors (corresponds to Go's npidle atomic.Int32).
    /// Used for debugging and load balancing decisions.
    npidle: std.atomic.Value(u32),

    /// Goroutine ID generator (corresponds to Go's goidgen atomic.Uint64).
    /// Thread-safe atomic counter for unique goroutine IDs.
    goidgen: std.atomic.Value(u32),

    // ==== Memory Management ====

    /// Allocator for managing dynamic memory.
    /// Used for processors array and other scheduler structures.
    allocator: std.mem.Allocator,

    // ==== Debug Configuration ====

    /// Enable debug mode for scheduler operations.
    /// Controls debug output, state validation, and verbose logging.
    debug_mode: bool = false,

    // =====================================================
    // Initialization and Cleanup
    // =====================================================

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

        return Self{
            .runq = GlobalQueue.init(),
            .processors = processors,
            .nproc = nproc,
            .pidle = null,
            .npidle = std.atomic.Value(u32).init(0),
            .goidgen = std.atomic.Value(u32).init(0),
            .allocator = allocator,
            .debug_mode = debug_mode,
        };
    }

    /// Clean up scheduler resources.
    pub fn deinit(self: *Self) void {
        const lifecycle = @import("../lifecycle.zig");

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

    // =====================================================
    // Basic Scheduler Operations
    // =====================================================

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

    // =====================================================
    // Global Queue Operations
    // =====================================================
    pub usingnamespace @import("runq_global_ops.zig").bind(@This());

    // =====================================================
    // Local Queue Operations
    // =====================================================
    pub usingnamespace @import("runq_local_ops.zig").bind(@This(), WorkItem);

    // =====================================================
    // Main Scheduling Loop
    // =====================================================
    pub usingnamespace @import("loop.zig").bind(@This(), WorkItem, GSrc);
};
