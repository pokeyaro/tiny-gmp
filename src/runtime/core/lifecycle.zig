//! Goroutine lifecycle management
//!
//! Handles creation, scheduling, and cleanup of goroutines with proper memory management.
//! Provides both targeted and automatic processor selection for goroutine placement.

const std = @import("std");
const scheduler = @import("scheduler.zig");
const goroutine = @import("../entity/goroutine.zig");
const processor = @import("../entity/processor.zig");

const schedt = scheduler.schedt;
const G = goroutine.G;
const P = processor.P;

// Global round-robin cursor for selecting target P.
// Single-threaded demo only; not safe for concurrent newproc calls.
var current_p_index: u32 = 0;

/// Create a new goroutine and schedule it (equivalent to Go's newproc).
/// Follows Go's scheduling strategy: put on current P's local queue.
pub fn newproc(sched: *schedt, p: *P, func: ?*const fn () void) !void {
    const gid = sched.nextGID();

    // Heap allocate the goroutine to avoid lifetime issues.
    const g = try sched.allocator.create(G);
    g.* = G.init(gid, func);

    // Put on specified P's local queue (handles overflow internally).
    sched.runqput(p, g);

    // TODO: wakep() - wake idle P if needed.
}

/// Create a goroutine on an automatically chosen P (round-robin).
/// Convenience wrapper around `newproc`.
pub fn newprocAuto(sched: *schedt, task: ?*const fn () void) !void {
    // Pick P via round-robin cursor (single-threaded demo; not thread-safe).
    // TODO: move cursor into `schedt` or make it atomic when multi-threaded;
    //       later replace with proper M→P binding / load-aware selection.
    const target_p = &sched.processors[current_p_index];
    current_p_index = (current_p_index + 1) % sched.nproc;

    return newproc(sched, target_p, task);
}

/// Destroy a goroutine and clean up resources.
pub fn destroyproc(sched: *schedt, g: *G) void {
    // Clear any remaining links.
    g.clearLink();

    // Deallocate the goroutine.
    sched.allocator.destroy(g);
}
