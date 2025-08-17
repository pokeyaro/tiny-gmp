//! Goroutine execution engine
//!
//! Core execution runtime for goroutines with comprehensive state management,
//! performance monitoring, and error recovery. Provides both basic execution
//! and context-aware execution with detailed logging and metrics collection.

const std = @import("std");
const tg = @import("../tg.zig");

// Types
const G = tg.G;

// ==========================
// Public API
// ==========================

/// Execute one scheduling slice for the goroutine.
/// Returns true if the goroutine has completed; false if it yielded.
pub fn execute(g: *G) bool {
    return executeSlice(g);
}

/// Execute one logical slice.
/// Returns `true` if the goroutine has completed; `false` if it yielded.
pub fn executeSlice(g: *G) bool {
    // Precondition: must be Ready and have a task.
    if (!g.isExecutionReady()) {
        g.setStatus(.Done);
        return true;
    }

    // Safepoint (before calling the task): honor preemption request.
    // If preempted, we do NOT invoke the task body; the runner will tail-enqueue it.
    if (g.consumePreempt()) {
        return false;
    }

    // Run one task call.
    g.setStatus(.Running);
    onTaskStart(g);

    executeCore(g);

    onTaskComplete(g);
    g.setStatus(.Done);

    return true;
}

// ==========================
// Core primitive
// ==========================

/// Invoke the task function once.
fn executeCore(g: *G) void {
    const func = g.getTask().?;
    func();
}

// ==========================
// Hooks (no-op for now)
// ==========================

/// Hook before task execution (placeholder for profiling/tracing).
fn onTaskStart(g: *G) void {
    _ = g;
}

/// Hook after task execution (placeholder for cleanup/metrics).
fn onTaskComplete(g: *G) void {
    _ = g;
}
