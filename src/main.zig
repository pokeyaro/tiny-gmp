//! Main entry point for Tiny-GMP scheduler
//!
//! Handles allocator selection based on build mode and launches appropriate
//! application workflow (demo for Debug, production API for Release).

const std = @import("std");
const builtin = @import("builtin");

// =====================================================
// Main Entry Point - Allocator Selection & App Launch
// =====================================================

pub fn main() !void {
    if (builtin.mode == .Debug) {
        try runDebugDemo();
    } else {
        try runProduction();
    }
}

fn runDebugDemo() !void {
    const demo = @import("examples/demo.zig");

    // Debug mode: Run stress test demo with GPA for memory leak detection.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    try demo.runStressTest(gpa.allocator());
}

fn runProduction() !void {
    const app = @import("runtime/app.zig");

    // Release mode: Run production scheduler with system allocator.
    const config = app.AppConfig{
        .total_goroutines = 64,
        .task_functions = null, // Must be provided in production.
        .debug_mode = false,
        .scheduler_strategy = .OneToOne,
    };
    try app.start(config, std.heap.c_allocator);
}
