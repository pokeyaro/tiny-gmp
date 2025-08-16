//! Goroutine lifecycle management
//!
//! Handles creation, scheduling, and cleanup of goroutines with proper memory management.
//! Provides both targeted and automatic processor selection for goroutine placement.

const std = @import("std");
const tg = @import("../tg.zig");

// Types
const schedt = tg.scheduler.schedt;
const G = tg.G;
const P = tg.P;

// Global round-robin cursor for selecting target P.
// Single-threaded demo only; not safe for concurrent newproc calls.
var current_p_index: u32 = 0;

/// Create a new goroutine and schedule it (equivalent to Go's newproc).
/// Follows Go's scheduling strategy: put on current P's local queue.
///
/// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func newproc").
pub fn newproc(sched: *schedt, p: *P, func: ?*const fn () void) !void {
    const gid = sched.nextGID();

    // Heap allocate the goroutine to avoid lifetime issues.
    const g = try sched.allocator.create(G);
    g.* = G.init(gid, func);

    // v7: deterministic per-G work length: 1..5
    g.setSteps(1 + @as(u16, @intCast(gid % 5)));

    // Put on specified P's local queue with runnext preference.
    sched.runqput(p, g, true);

    // Only after scheduler started, wake one idle P (if any).
    if (sched.main_started) {
        _ = sched.wakep();
    }
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
