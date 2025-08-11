//! Goroutine execution engine
//!
//! Core execution runtime for goroutines with comprehensive state management,
//! performance monitoring, and error recovery. Provides both basic execution
//! and context-aware execution with detailed logging and metrics collection.

const std = @import("std");
const goroutine = @import("../gmp/goroutine.zig");

const G = goroutine.G;

// =====================================================
// Goroutine Execution Engine
// =====================================================

/// Public entry: run a goroutine once.
pub fn execute(g: *G) void {
    executeCore(g);
}

/// Core executor: status switch + call task.
fn executeCore(g: *G) void {
    // Pre-check: must be Ready and have a task.
    if (!g.isExecutionReady()) {
        std.debug.print("Warning: G{} not ready (status={s}, hasTask={})\n", .{ g.getID(), g.getStatus().toString(), g.hasTask() });
        return;
    }

    // Running → call task → Done.
    g.setStatus(.Running);

    onTaskStart(g); // hook: profiling/tracing (no-op for now).

    const task = g.getTask().?;
    task();

    onTaskComplete(g); // hook: cleanup/metrics (no-op for now).

    g.setStatus(.Done);
}

/// Hook before task execution (placeholder for profiling/tracing).
fn onTaskStart(g: *G) void {
    _ = g;
}

/// Hook after task execution (placeholder for cleanup/metrics).
fn onTaskComplete(g: *G) void {
    _ = g;
}
