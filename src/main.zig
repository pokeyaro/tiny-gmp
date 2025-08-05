const std = @import("std");

// =====================================================
// G (Goroutine) Definitions
// =====================================================

var next_gid: u32 = 0; // G ID counter

/// Status enum for Goroutine lifecycle.
const GStatus = enum {
    Ready, // Waiting to be scheduled
    Running, // Currently executing
    Done, // Finished execution

    /// Convert a GStatus enum to a human-readable string.
    pub fn toString(self: GStatus) []const u8 {
        return switch (self) {
            .Ready => "Ready",
            .Running => "Running",
            .Done => "Done",
        };
    }
};

/// G represents a goroutine, the basic unit of execution.
const G = struct {
    id: u32, // Unique goroutine ID
    status: GStatus = .Ready, // Current execution status
    task: ?*const fn () void, // Pointer to task function

    /// Initialize a new Goroutine with an auto-incremented ID and given task.
    fn init(task: ?*const fn () void) G {
        const gid = next_gid;
        next_gid += 1;
        return G{
            .id = gid,
            .status = .Ready,
            .task = task,
        };
    }
};

// =====================================================
// P (Processor) Definitions
// =====================================================

const RUNQ_SIZE = 256; // Local run queue size constant

var next_pid: u32 = 0; // P ID counter

/// Status enum for Processor (P).
const PStatus = enum {
    Idle, // No work assigned
    Running, // Actively executing Gs

    /// Convert a PStatus enum to a human-readable string.
    pub fn toString(self: PStatus) []const u8 {
        return switch (self) {
            .Idle => "Idle",
            .Running => "Running",
        };
    }
};

/// P represents a processor, which manages its own goroutine queue.
const P = struct {
    id: u32, // Unique processor ID
    status: PStatus = .Idle, // Execution status
    runq: [RUNQ_SIZE]?*G, // Circular run queue
    runqhead: u32 = 0, // Head index of the run queue
    runqtail: u32 = 0, // Tail index of the run queue
    runnext: ?*G = null, // Fast-path slot for next G

    /// Create a new processor with an empty run queue and a unique ID.
    fn init() P {
        const pid = next_pid;
        next_pid += 1;
        return P{
            .id = pid,
            .status = .Idle,
            .runq = [_]?*G{null} ** RUNQ_SIZE,
            .runqhead = 0,
            .runqtail = 0,
            .runnext = null,
        };
    }

    /// Get the number of goroutines in the run queue.
    fn size(self: *const P) u32 {
        return (self.runqtail - self.runqhead) % RUNQ_SIZE;
    }

    /// Check if the processor has no goroutines left.
    fn isEmpty(self: *const P) bool {
        return self.size() == 0 and self.runnext == null;
    }

    /// Check if the run queue is full (excluding runnext slot).
    fn isFull(self: *const P) bool {
        return self.size() >= (RUNQ_SIZE - 1); // Reserve one slot as buffer
    }

    /// Attempt to enqueue a goroutine into the processor.
    /// Returns true if successful, false if full.
    fn enqueue(self: *P, g: *G) bool {
        if (self.runnext == null) {
            self.runnext = g;
            return true;
        }

        if (self.isFull()) return false;

        self.runq[self.runqtail % RUNQ_SIZE] = g;
        self.runqtail += 1;
        return true;
    }

    /// Dequeue the next runnable goroutine, prioritizing `runnext`.
    fn dequeue(self: *P) ?*G {
        if (self.runnext) |g| {
            self.runnext = null;
            return g;
        }

        if (self.size() == 0) return null;

        const g = self.runq[self.runqhead % RUNQ_SIZE];
        self.runq[self.runqhead % RUNQ_SIZE] = null;
        self.runqhead += 1;
        return g;
    }

    /// Print the current goroutine queue status of this processor.
    fn display(self: *const P) void {
        std.debug.print("P{}: [", .{self.id});

        var first = true;

        // Show the G in runnext
        if (self.runnext) |g| {
            std.debug.print("G{}", .{g.id});
            first = false;
        }

        // Show all Gs in the queue
        var i = self.runqhead;
        while (i != self.runqtail) {
            if (self.runq[i % RUNQ_SIZE]) |g| {
                if (!first) std.debug.print(", ", .{});
                std.debug.print("G{}", .{g.id});
                first = false;
            }
            i += 1;
        }

        std.debug.print("]\n", .{});
    }
};

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
// Task Functions
// =====================================================

fn task1() void {
    std.debug.print("  -> Hello from task1!\n", .{});
}

fn task2() void {
    std.debug.print("  -> Computing 1+1={}\n", .{2});
}

fn task3() void {
    std.debug.print("  -> Execute shell `{s}` commands!\n", .{"ls -l"});
}

// =====================================================
// Main Entry Point
// =====================================================

pub fn main() !void {
    std.debug.print("=== Tiny-GMP V2 ===\n", .{});

    // Create processors
    var processors: [4]P = [_]P{
        P.init(), P.init(), P.init(), P.init(),
    };

    // Create goroutines
    var goroutines: [10]G = undefined;
    const tasks = [_](?*const fn () void){ task1, task2, task3 };
    for (0..10) |i| {
        goroutines[i] = G.init(tasks[i % tasks.len]);
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
