//! Production scheduler implementation
//!
//! Core GMP (Goroutine-Machine-Processor) scheduling algorithms implementing Go's
//! runtime scheduler. Features work-stealing, load balancing, and batch processing
//! with comprehensive debug support and performance monitoring capabilities.

const std = @import("std");
const tg = @import("../../tg.zig");

// Modules
const scheduler_config = tg.config.scheduler;
const local_queue = tg.queue.local_queue;
const shuffle = tg.lib.algo.shuffle;
const lifecycle = tg.lifecycle;

// Types
const G = tg.G;
const P = tg.P;
const GlobalQueue = tg.queue.global_queue.GlobalQueue;
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
    pub const Self = @This();

    g: *G,
    src: GSrc,

    /// Typed source accessor.
    pub fn source(self: Self) GSrc {
        return self.src;
    }

    /// Human-readable source label.
    pub fn sourceName(self: Self) []const u8 {
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

    // === Core Scheduling Fields ===

    /// Global runnable queue (corresponds to Go's runq gQueue).
    runq: GlobalQueue,

    /// Array of processors, each P manages local goroutine scheduling.
    /// Corresponds to Go's allp []*p array (all processors, active + idle).
    /// Go also uses separate pidle linked list for idle P management.
    processors: []P,

    /// Number of processors (corresponds to Go's gomaxprocs).
    /// Fixed at initialization, matching CPU core count.
    nproc: u32,

    // === Statistics and State Fields ===

    /// Head of idle processor linked list (corresponds to Go's pidle).
    /// Uses intrusive linked list via P.link
    pidle: ?*P = null,

    /// Number of idle processors (corresponds to Go's npidle atomic.Int32).
    /// Used for debugging and load balancing decisions.
    npidle: std.atomic.Value(u32) = .init(0),

    /// Goroutine ID generator (corresponds to Go's goidgen atomic.Uint64).
    /// Thread-safe atomic counter for unique goroutine IDs.
    goidgen: std.atomic.Value(u64) = .init(1),

    // === Runtime State (Go: mainStarted) ===
    /// True once the scheduler main loop has started (Go's mainStarted).
    main_started: bool = false,

    // === Memory Management ===

    /// Allocator for managing dynamic memory.
    /// Used for processors array and other scheduler structures.
    allocator: std.mem.Allocator,

    // === Debug Configuration ===

    /// Enable debug mode for scheduler operations.
    /// Controls debug output, state validation, and verbose logging.
    debug_mode: bool = false,

    // === Mix in partials ===

    pub usingnamespace @import("ctor.zig").bind(Self); // initialization & destruction
    pub usingnamespace @import("basics.zig").bind(Self); // basic utilities for scheduler
    pub usingnamespace @import("pidle_ops.zig").bind(Self); // idle processor stack operations
    pub usingnamespace @import("runq_local_ops.zig").bind(Self, WorkItem); // local run queue operations
    pub usingnamespace @import("runq_global_ops.zig").bind(Self, WorkItem); // global run queue operations
    pub usingnamespace @import("runner.zig").bind(Self); // run & finalize goroutine execution
    pub usingnamespace @import("steal_work.zig").bind(Self, WorkItem); // work stealing logic (steal tasks from other Ps)
    pub usingnamespace @import("find_work.zig").bind(Self, WorkItem); // locate runnable work items
    pub usingnamespace @import("loop.zig").bind(Self); // main scheduling loop
    pub usingnamespace @import("display.zig").bind(Self); // display & debug utilities
};
