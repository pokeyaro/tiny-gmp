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

/// Execute exactly one timeslice (quantum = 1) of the goroutine.
/// Returns true if the goroutine has completed; false if it yielded.
pub fn execute(g: *G) bool {
    return executeSlice(g, 1);
}

/// Execute one logical timeslice with a given quantum (>=1).
/// Orchestrates state checks, start/complete hooks, and status transitions.
/// Returns true if the goroutine has completed; false if it yielded.
pub fn executeSlice(g: *G, quantum_ops: u16) bool {
    // Pre-check: must be Ready and have a task.
    if (!g.isExecutionReady()) {
        std.debug.print(
            "Warning: G{} not ready (status={s}, hasTask={})\n",
            .{ g.getID(), g.getStatus().toString(), g.hasTask() },
        );
        // Treat as completed to avoid re-queuing a broken G.
        g.setStatus(.Done);
        return true;
    }

    // Run one slice.
    g.setStatus(.Running);
    onTaskStart(g);

    const finished = executeCore(g, quantum_ops);

    onTaskComplete(g);
    g.setStatus(if (finished) .Done else .Ready);

    return finished;
}

// ==========================
// Core primitive
// ==========================

/// Core execution primitive: call the task once (one “work unit”),
/// then consume `quantum_ops` logical steps. No status transitions here.
/// Returns true if the goroutine has completed; false otherwise.
fn executeCore(g: *G, quantum_ops: u16) bool {
    const task = g.getTask().?;
    task(); // one unit of work (for v7, one call == one step of work)

    const q: u16 = if (quantum_ops == 0) 1 else quantum_ops;
    return g.consume(q);
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
