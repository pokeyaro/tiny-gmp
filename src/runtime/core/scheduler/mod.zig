//! Production scheduler implementation
//!
//! Core GMP (Goroutine-Machine-Processor) scheduling algorithms implementing Go's
//! runtime scheduler. Features work-stealing, load balancing, and batch processing
//! with comprehensive debug support and performance monitoring capabilities.

const std = @import("std");
const tg = @import("../../tg.zig");
const Types = @import("types.zig");

// Types
const P = tg.P;
const TimerEntry = Types.TimerEntry;
const GlobalQueue = tg.queue.global_queue.GlobalQueue;

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

    // === Scheduling timeline state ===

    /// Global tick counter, incremented at the start of every scheduling round.
    ticks: u64 = 0,

    /// How many ticks between each preemption pass (default: 7).
    preempt_period: u32 = 7,

    /// Next tick at which a preemption pass should run.
    next_preempt_tick: u64 = 7,

    // === Timers ===

    /// Pending timer entries; each entry says "wake G at deadline tick".
    timers: std.ArrayListUnmanaged(TimerEntry) = .{},

    // === Mix in partials ===

    pub usingnamespace @import("ctor.zig").bind(Self); // initialization & destruction
    pub usingnamespace @import("basics.zig").bind(Self); // basic utilities for scheduler
    pub usingnamespace @import("pidle_ops.zig").bind(Self); // idle processor stack operations
    pub usingnamespace @import("runq_local_ops.zig").bind(Self); // local run queue operations
    pub usingnamespace @import("runq_global_ops.zig").bind(Self); // global run queue operations
    pub usingnamespace @import("runner.zig").bind(Self); // run & finalize goroutine execution
    pub usingnamespace @import("steal_work.zig").bind(Self); // work stealing logic (steal tasks from other Ps)
    pub usingnamespace @import("find_work.zig").bind(Self); // locate runnable work items
    pub usingnamespace @import("timer.zig").bind(Self); // scheduling timeline: tick management + periodic preemption
    pub usingnamespace @import("loop.zig").bind(Self); // main scheduling loop
    pub usingnamespace @import("display.zig").bind(Self); // display & debug utilities
};
