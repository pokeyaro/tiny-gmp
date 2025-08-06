const std = @import("std");
const tasks = @import("../../examples/tasks.zig");
const goroutine = @import("../entity/goroutine.zig");
const processor = @import("../entity/processor.zig");

// Import types
const G = goroutine.G;
const GStatus = goroutine.GStatus;
const P = processor.P;
const PStatus = processor.PStatus;

// =====================================================
// Scheduling Logic Functions
// =====================================================

/// Evenly assign goroutines to processors in round-robin fashion.
/// This creates a balanced distribution where each processor gets similar workload.
fn assignTasks(goroutines: []G, processors: []P) void {
    for (goroutines, 0..) |*g, i| {
        const p_index = i % processors.len;
        if (!processors[p_index].runqput(g)) {
            std.debug.print("Warning: P{} queue is full!\n", .{p_index});
        }
    }
}

/// Custom assignment with explicit runnext and queue distribution.
/// This creates an uneven distribution to better demonstrate the GMP model.
/// Each processor gets a specific number of goroutines for educational purposes.
fn assignTasksCustom(goroutines: []G, processors: []P) void {
    // Define how many goroutines each processor should get:
    // (runnext_count, queue_count) for each processor
    const assignments = [_]struct { runnext: usize, queue: usize }{
        .{ .runnext = 1, .queue = 3 }, // P0: 4 total goroutines (1 runnext + 3 queue)
        .{ .runnext = 1, .queue = 3 }, // P1: 4 total goroutines (1 runnext + 3 queue)
        .{ .runnext = 1, .queue = 2 }, // P2: 3 total goroutines (1 runnext + 2 queue)
        .{ .runnext = 1, .queue = 2 }, // P3: 3 total goroutines (1 runnext + 2 queue)
        .{ .runnext = 1, .queue = 0 }, // P4: 1 total goroutine  (1 runnext + 0 queue)
    };

    var g_index: usize = 0;

    // Distribute goroutines according to the assignment configuration
    for (processors, 0..) |*p, p_index| {
        const assignment = assignments[p_index];
        const total_needed = assignment.runnext + assignment.queue;
        var assigned: usize = 0;

        // Assign the required number of goroutines to this processor
        while (assigned < total_needed and g_index < goroutines.len) {
            if (!p.runqput(&goroutines[g_index])) {
                std.debug.print("Warning: P{} queue is full!\n", .{p_index});
                break;
            }
            g_index += 1;
            assigned += 1;
        }
    }
}

/// Execute the scheduling loop until all goroutines are finished.
/// This is the heart of the GMP scheduler simulation.
fn runScheduler(processors: []P) void {
    var round: u32 = 0;

    while (true) {
        round += 1;
        var found_work = false;

        // Round-robin through all processors to find work
        for (processors) |*p| {
            const result = p.runqget();
            if (result.g) |g| {
                // Only print round header when we find the first work of this round
                if (!found_work) {
                    std.debug.print("\n--- Round {} ---\n", .{round});
                }

                found_work = true;

                // Update processor status to running
                p.setStatus(.Running);

                // Show which goroutine is being executed and from where (runnext vs queue)
                std.debug.print("P{}: Executing G{} (from {s})\n", .{ p.id, g.id, result.sourceName() });

                // Execute the goroutine's task
                g.status = .Running;
                if (g.task) |task| {
                    task(); // This calls the actual task function (task1, task2, etc.)
                }
                g.status = .Done;

                std.debug.print("P{}: G{} completed\n", .{ p.id, g.id });

                // Sync processor status based on remaining work
                p.syncStatus();

                // Only execute one goroutine per round for better visualization
                break;
            }
        }

        // If no work was found in any processor, scheduling is complete
        if (!found_work) {
            std.debug.print("\nScheduler: All processors idle, scheduling finished\n", .{});
            break;
        }
    }
}

// =====================================================
// Public Scheduler Interface
// =====================================================

/// Main scheduler entry point - runs the complete GMP simulation.
/// This demonstrates Go's GMP (Goroutine-Machine-Processor) model.
pub fn run() !void {
    std.debug.print("=== Tiny-GMP V3 ===\n", .{});

    // Create 5 processors (P) - each represents a logical processor
    var processors: [5]P = [_]P{
        P.init(), P.init(), P.init(), P.init(), P.init(),
    };

    // Create 15 goroutines (G) with random task assignments
    var goroutines: [15]G = undefined;

    // Initialize random number generator with current timestamp as seed
    var rng = std.Random.DefaultPrng.init(blk: {
        const seed: u64 = @intCast(std.time.timestamp());
        break :blk seed;
    });
    const random = rng.random();

    // Convert compile-time task function array to runtime array
    var task_funcs: [20]?*const fn () void = undefined;
    inline for (0..20) |i| {
        task_funcs[i] = tasks.TASK_FUNCTIONS[i];
    }

    // Assign random tasks to each goroutine
    for (0..15) |i| {
        const index = random.uintLessThan(usize, 20);
        goroutines[i] = G.init(task_funcs[index]);
    }

    // Shuffle the goroutines array to randomize assignment order
    for (0..goroutines.len) |i| {
        const j = random.uintLessThan(usize, goroutines.len);
        const temp = goroutines[i];
        goroutines[i] = goroutines[j];
        goroutines[j] = temp;
    }

    // Distribute goroutines to processors using custom assignment strategy
    assignTasksCustom(&goroutines, &processors);

    // Display initial assignment to show runnext optimization
    std.debug.print("\n=== Initial Assignment ===\n", .{});
    for (processors) |p| {
        p.display(); // Shows "P0: next: G5; queue: [G1, G2, G3]" format
    }

    // Run the scheduler simulation
    runScheduler(&processors);

    // Display final statistics
    std.debug.print("\n=== Final Status ===\n", .{});
    for (processors) |p| {
        std.debug.print("P{}: {} tasks remaining\n", .{ p.id, p.totalGoroutines() });
    }
}
