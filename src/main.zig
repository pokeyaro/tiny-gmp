const std = @import("std");

const GStatus = enum {
    Ready,
    Running,
    Done,

    pub fn toString(self: GStatus) []const u8 {
        return switch (self) {
            .Ready => "Ready",
            .Running => "Running",
            .Done => "Done",
        };
    }
};

const G = struct {
    id: u32,
    status: GStatus = .Ready,
    task: ?*const fn () void,

    fn init(id: u32, task: ?*const fn () void) G {
        return G{
            .id = id,
            .status = .Ready,
            .task = task,
        };
    }
};

fn task1() void {
    std.debug.print("  -> G1: Hello from task1!\n", .{});
}

fn task2() void {
    std.debug.print("  -> G2: Computing 1+1={}\n", .{2});
}

fn task3() void {
    std.debug.print("  -> G3: Execute shell `{s}` commands!\n", .{"ls -l"});
}

pub fn main() !void {
    std.debug.print("=== Tiny-GMP V1 ===\n", .{});

    // Fixed array of goroutines
    var runqueue: [3]G = [_]G{
        G.init(0, task1),
        G.init(1, task2),
        G.init(2, task3),
    };

    // Scheduling loop
    var round: u32 = 0;
    while (true) {
        round += 1;
        std.debug.print("\n--- Round {} ---\n", .{round});

        var found_ready = false;

        // Find Ready goroutines and execute them
        for (&runqueue) |*g| {
            if (g.status == .Ready) {
                found_ready = true;

                std.debug.print("Scheduler: Executing G{}\n", .{g.id});

                // Execute the goroutine
                g.status = .Running;
                if (g.task) |task| {
                    task();
                }
                g.status = .Done;

                std.debug.print("Scheduler: G{} completed\n", .{g.id});
                break; // Execute one G at a time
            }
        }

        // Exit if no Ready goroutines found
        if (!found_ready) {
            std.debug.print("\nScheduler: No more ready goroutines, scheduling finished\n", .{});
            break;
        }
    }

    // Display final status
    std.debug.print("\n=== Final Status ===\n", .{});
    for (runqueue) |g| {
        std.debug.print("G{}: {s}\n", .{ g.id, g.status.toString() });
    }
}
