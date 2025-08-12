//! Scheduler application layer
//!
//! Provides high-level APIs for starting and configuring the scheduler,
//! including configuration validation and convenient wrapper functions.

const std = @import("std");
const tg = @import("tg.zig");

// Modules
const lifecycle = tg.lifecycle;
const scheduler_config = tg.config.scheduler;

// Types
const schedt = tg.scheduler.schedt;

// =====================================================
// Configuration Structures
// =====================================================

/// Configuration for scheduler application.
pub const AppConfig = struct {
    /// Total number of goroutines to create.
    total_goroutines: usize = 64,

    /// Collection of task functions.
    task_functions: ?[]const *const fn () void,

    /// Debug output and logging switch.
    debug_mode: bool = false,

    /// Scheduling strategy.
    scheduler_strategy: scheduler_config.ScalingStrategy = .OneToOne,
};

// =====================================================
// Core Scheduler API
// =====================================================

/// Start scheduler with custom configuration (core functionality).
pub fn start(config: AppConfig, allocator: std.mem.Allocator) !void {
    const tasks = config.task_functions orelse {
        std.debug.print("\x1b[31mProduction scheduler requires valid task functions!\x1b[0m\n", .{});
        return error.NoTaskFunctions;
    };

    if (tasks.len == 0) {
        std.debug.print("\x1b[31mTask functions array cannot be empty!\x1b[0m\n", .{});
        return error.EmptyTaskFunctions;
    }

    if (config.total_goroutines == 0) {
        std.debug.print("\x1b[31mtotal_goroutines must be > 0\x1b[0m\n", .{});
        return error.InvalidGoroutineCount;
    }

    // Apply scheduler strategy.
    _ = scheduler_config.initGlobalConfig(config.scheduler_strategy);

    // Initialize the scheduler.
    var sched = try schedt.init(allocator, config.debug_mode);
    defer sched.deinit();

    // Create goroutines based on config.
    for (0..config.total_goroutines) |i| {
        const task_func = tasks[i % tasks.len];
        try lifecycle.newprocAuto(&sched, task_func);
    }

    // Run the scheduler.
    sched.schedule();
}

/// Start scheduler with debug output (convenience function).
pub fn startWithDebug(config: AppConfig, allocator: std.mem.Allocator) !void {
    if (config.debug_mode) {
        scheduler_config.getGlobalConfig().displayConfig();
        std.debug.print("Starting scheduler with {} goroutines\n", .{config.total_goroutines});
    }

    try start(config, allocator);

    if (config.debug_mode) {
        std.debug.print("Scheduler completed successfully\n", .{});
    }
}
