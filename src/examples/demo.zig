const std = @import("std");
const app = @import("../runtime/app.zig");
const tasks = @import("tasks.zig");
const scheduler_config = @import("../runtime/config/scheduler_config.zig");

// =====================================================
// Demo and Testing Functions
// =====================================================

/// Run the complete scheduler stress test workflow.
pub fn runStressTest(allocator: std.mem.Allocator) !void {
    std.debug.print("=== Tiny-GMP V8 - STRESS TEST ===\n\n", .{});

    const config = app.AppConfig{
        .total_goroutines = 10000,
        .task_functions = &tasks.TASK_FUNCTIONS,
        .debug_mode = true,
        .scheduler_strategy = .HalfProcessors,
    };

    // Display goroutine creation process (demo-specific detailed output).
    std.debug.print("=== Creating {} Goroutines (Testing Overflow Logic) ===\n\n", .{config.total_goroutines});

    // Use config to initialize and run scheduler
    scheduler_config.initGlobalConfig(config.scheduler_strategy).displayConfig();

    try runStressTestWithCustomOutput(config, allocator);
}

/// Stress test with custom output (internal function).
fn runStressTestWithCustomOutput(config: app.AppConfig, allocator: std.mem.Allocator) !void {
    const scheduler_mod = @import("../runtime/core/scheduler/mod.zig");
    const lifecycle = @import("../runtime/core/lifecycle.zig");
    const schedt = scheduler_mod.schedt;

    // Initialize the scheduler with debug output configuration.
    var sched = try schedt.init(allocator, config.debug_mode);
    defer sched.deinit();

    std.debug.print("Scheduler initialized with {} processors\n", .{sched.nproc});

    // Create goroutines with detailed logging.
    for (0..config.total_goroutines) |i| {
        const tfs = config.task_functions.?;
        const task_index = i % tfs.len;
        const task_func = tfs[task_index];

        try lifecycle.newprocAuto(&sched, task_func);

        // Only print first 10 and last 10 to avoid spam.
        const head = 10;
        const tail = 10;
        if (i < head or i >= config.total_goroutines - tail) {
            std.debug.print("Created G{} with task{}\n", .{ i + 1, task_index + 1 });
        } else if (i == head) {
            std.debug.print("... creating goroutines G11 to G{} ...\n", .{config.total_goroutines - 10});
        }
    }

    std.debug.print("\nTotal goroutines created: {}\n", .{config.total_goroutines});

    // Display initial assignment (should show overflow to global queue).
    std.debug.print("\n=== Initial Assignment (After Overflow) ===\n", .{});
    for (sched.processors) |*p| {
        p.display();
    }

    // Display global queue status.
    std.debug.print("Global Queue: {} goroutines\n", .{sched.runqsize()});

    // Start the scheduler.
    std.debug.print("\n=== Starting Scheduler ===\n", .{});
    sched.schedule();

    std.debug.print("\n=== Stress Test Completed Successfully ===\n", .{});
}
