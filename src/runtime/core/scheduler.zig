const std = @import("std");
const tasks = @import("../../examples/tasks.zig");
const goroutine = @import("../entity/goroutine.zig");
const processor = @import("../entity/processor.zig");

// Type aliases for convenience
const G = goroutine.G;
const GStatus = goroutine.GStatus;
const P = processor.P;
const PStatus = processor.PStatus;

// =====================================================
// Scheduling Logic Functions
// =====================================================

/// Evenly assign goroutines to processors in round-robin fashion.
fn assignTasks(goroutines: []G, processors: []P) void {
    for (goroutines, 0..) |*g, i| {
        const p_index = i % processors.len;
        if (!processors[p_index].enqueue(g)) {
            std.debug.print("Warning: P{} queue is full!\n", .{p_index});
        }
    }
}

/// Execute the scheduling loop until all goroutines are finished.
fn runScheduler(processors: []P) void {
    var round: u32 = 0;
    while (true) {
        round += 1;
        std.debug.print("\n--- Round {} ---\n", .{round});

        var found_work = false;

        for (processors) |*p| {
            if (p.dequeue()) |g| {
                found_work = true;

                std.debug.print("P{}: Executing G{}\n", .{ p.id, g.id });

                g.status = .Running;
                if (g.task) |task| {
                    task();
                }
                g.status = .Done;

                std.debug.print("P{}: G{} completed\n", .{ p.id, g.id });
                break;
            }
        }

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
pub fn run() !void {
    std.debug.print("=== Tiny-GMP V2 ===\n", .{});

    // Create processors
    var processors: [4]P = [_]P{
        P.init(), P.init(), P.init(), P.init(),
    };

    // Create goroutines
    var goroutines: [10]G = undefined;
    const task_functions = tasks.TASK_FUNCTIONS;
    for (0..10) |i| {
        goroutines[i] = G.init(task_functions[i % task_functions.len]);
    }

    // Assign and display
    assignTasks(&goroutines, &processors);

    std.debug.print("\n=== Initial Assignment ===\n", .{});
    for (processors) |p| {
        p.display();
    }

    // Run scheduler
    runScheduler(&processors);

    // Final state
    std.debug.print("\n=== Final Status ===\n", .{});
    for (processors) |p| {
        std.debug.print("P{}: {} tasks remaining\n", .{ p.id, p.size() });
    }
}
