//! Production scheduler implementation
//!
//! Core GMP (Goroutine-Machine-Processor) scheduling algorithms implementing Go's
//! runtime scheduler. Features work-stealing, load balancing, and batch processing
//! with comprehensive debug support and performance monitoring capabilities.

const std = @import("std");
const goroutine = @import("../entity/goroutine.zig");
const processor = @import("../entity/processor.zig");
const local_queue = @import("../queue/local_queue.zig");
const global_queue = @import("../queue/global_queue.zig");
const scheduler_config = @import("../config/scheduler_config.zig");
const shuffle = @import("../../lib/algo/shuffle.zig");

// Import types
const G = goroutine.G;
const P = processor.P;
const GlobalQueue = global_queue.GlobalQueue;
const SchedulerConfig = scheduler_config.SchedulerConfig;

/// Source of a goroutine when it gets selected to run.
pub const GSrc = enum {
    Runnext,
    Runq,
    Global,

    /// Convert a GSrc enum to a human-readable string.
    pub fn toString(self: GSrc) []const u8 {
        return switch (self) {
            .Runnext => "runnext",
            .Runq => "runq",
            .Global => "global",
        };
    }
};

/// Result type returned by runqget function.
/// Contains the goroutine and information about its source.
pub const WorkItem = struct {
    g: ?*G,
    src: GSrc,

    /// Typed source accessor.
    pub fn source(self: WorkItem) GSrc {
        return self.src;
    }

    /// Human-readable source label.
    pub fn sourceName(self: WorkItem) []const u8 {
        return self.src.toString();
    }
};

// =====================================================
// Scheduler Implementation
// =====================================================

/// Global scheduler state, matching Go's schedt structure.
///
/// Go source: https://github.com/golang/go/blob/master/src/runtime/runtime2.go (search for "type schedt struct").
pub const schedt = struct {
    const Self = @This();

    // =====================================================
    // Core Scheduler Data Structure
    // =====================================================

    // ==== Core Scheduling Fields ====

    /// Global runnable queue (corresponds to Go's runq gQueue).
    runq: GlobalQueue,

    /// Array of processors, each P manages local goroutine scheduling.
    /// Simplified design: we use array instead of Go's global allp + pidle linked list.
    processors: []P,

    /// Number of processors (corresponds to Go's gomaxprocs).
    /// Fixed at initialization, matching CPU core count.
    nproc: u32,

    // ==== Statistics and State Fields ====

    /// Number of idle processors (corresponds to Go's npidle atomic.Int32).
    /// Used for debugging and load balancing decisions.
    npidle: u32 = 0,

    /// Goroutine ID generator (corresponds to Go's goidgen atomic.Uint64).
    /// Thread-safe atomic counter for unique goroutine IDs.
    goidgen: std.atomic.Value(u32),

    // ==== Memory Management ====

    /// Allocator for managing dynamic memory.
    /// Used for processors array and other scheduler structures.
    allocator: std.mem.Allocator,

    // ==== Debug Configuration ====

    /// Enable debug mode for scheduler operations.
    /// Controls debug output, state validation, and verbose logging.
    debug_mode: bool = false,

    // =====================================================
    // Initialization and Cleanup
    // =====================================================

    /// Create processors array with sequential IDs.
    fn createProcessors(allocator: std.mem.Allocator, count: u32) ![]P {
        const processors = try allocator.alloc(P, count);
        for (processors, 0..) |*p, i| {
            p.* = P.init(@as(u32, @intCast(i))); // P0, P1, P2, P3...
        }
        return processors;
    }

    /// Initialize the global scheduler.
    pub fn init(allocator: std.mem.Allocator, debug_mode: bool) !Self {
        const nproc = scheduler_config.getProcessorCount();
        const processors = try createProcessors(allocator, nproc);

        return Self{
            .runq = GlobalQueue.init(),
            .processors = processors,
            .nproc = nproc,
            .npidle = 0,
            .goidgen = std.atomic.Value(u32).init(0),
            .allocator = allocator,
            .debug_mode = debug_mode,
        };
    }

    /// Clean up scheduler resources.
    pub fn deinit(self: *Self) void {
        const lifecycle = @import("lifecycle.zig");

        // Clean up global queue.
        while (self.runq.dequeue()) |g| {
            lifecycle.destroyproc(self, g);
        }

        // Clean up processor queues.
        for (self.processors) |*p| {
            if (p.runnext) |g| {
                lifecycle.destroyproc(self, g);
            }
            while (p.runq.dequeue()) |g| {
                lifecycle.destroyproc(self, g);
            }
        }

        // Original cleanup.
        self.runq.deinit();
        self.allocator.free(self.processors);
    }

    // =====================================================
    // Basic Scheduler Operations
    // =====================================================

    /// Generate next unique goroutine ID (thread-safe).
    pub fn nextGID(self: *Self) u32 {
        return self.goidgen.fetchAdd(1, .seq_cst) + 1;
    }

    /// Check if global queue is empty.
    pub fn isEmpty(self: *const Self) bool {
        return self.runq.isEmpty();
    }

    /// Get the number of goroutines in global queue.
    pub fn runqsize(self: *const Self) usize {
        return self.runq.size();
    }

    /// Display scheduler state for debugging.
    pub fn display(self: *const Self) void {
        std.debug.print("=== Scheduler Status ===\n", .{});
        std.debug.print("Processors: {}, Idle: {}\n", .{ self.nproc, self.npidle });
        std.debug.print("Global goroutines: {}\n", .{self.runq.size()});
        self.runq.display();

        for (self.processors, 0..) |*p, i| {
            std.debug.print("P{}: ", .{i});
            p.display();
        }
    }

    /// Debug-only helper to print a unified "start executing" line with source.
    fn logExecStart(self: *schedt, p: *P, g: *G, src: GSrc) void {
        if (!self.debug_mode) return;
        std.debug.print("P{}: Executing G{} (from {s})\n", .{ p.getID(), g.getID(), src.toString() });
    }

    // =====================================================
    // Global Queue Operations
    // =====================================================

    /// Add a goroutine to the global run queue.
    /// Matches Go's globrunqput() function.
    /// Note: Adapted to use batch interface for performance consistency.
    pub fn globrunqput(self: *schedt, gp: *G) void {
        // Clear goroutine scheduling link
        gp.clearLink();

        // Put in global queue using batch interface (single element).
        // This maintains consistency with global queue's batch-oriented design.
        var single_batch = [_]*G{gp};
        self.runq.enqueueBatch(&single_batch);

        // TODO: Check if need to wake idle P.
        if (self.npidle > 0) {
            // Has idle P, might need to wake one to handle.
            // self.wakep();  // Future implementation.
        }
    }

    /// Get a batch of goroutines from the global run queue.
    /// Matches Go's globrunqget() function.
    pub fn globrunqget(self: *Self, pp: *P, max: usize) ?*G {
        if (self.isEmpty()) return null;

        // Use half of the local capacity as a safety bound.
        const local_cap_half = pp.runq.capacity() / 2;

        // Determine the initial candidate batch size.
        var n = self.calculateBatchSize(max, local_cap_half);

        // Tighten with the actual available slots of the local queue.
        const available = pp.runq.capacity() - pp.runq.size();
        n = @min(n, available);

        // Defensive: if n == 0, nothing to pull.
        if (n == 0) return null;

        // We assert the precondition before dequeue; enqueue should not fail.
        std.debug.assert(n <= available);

        // Pull a batch from the global queue.
        const batch = self.runq.dequeueBatch(n);

        // Transfer batch to local queue (should not fail given the checks above).
        if (!batch.isEmpty()) {
            pp.runq.enqueueBatch(batch) catch {
                // Truly unreachable if the pre-checks are correct.
                unreachable;
            };
        }

        return batch.immediate_g;
    }

    /// Calculate optimal batch size for load balancing.
    /// Matches Go's batch size calculation algorithm.
    fn calculateBatchSize(self: *Self, max: usize, local_cap_half: usize) usize {
        const qs = self.runqsize();
        if (qs == 0) return 0;

        var n = qs / self.nproc + 1; // Base on even distribution + 1.
        if (n > qs / 2) n = qs / 2; // No more than half of global queue.
        if (max > 0 and n > max) n = max; // Limit only when caller explicitly specifies max.
        if (n > local_cap_half) n = local_cap_half; // Local half-capacity protection.

        return n;
    }

    // =====================================================
    // Local Queue Operations
    // =====================================================

    /// Put goroutine on local run queue.
    /// Uses the runnext optimization: new goroutines go to runnext first.
    /// Handles local queue overflow by transferring half to global queue.
    ///
    /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func runqput").
    pub fn runqput(self: *schedt, p: *P, g: *G) void {
        // Fast path: use runnext if available.
        if (!p.hasRunnext()) {
            p.setRunnext(g);
            return;
        }

        // Slow path: try to add to the main queue.
        if (p.localEnqueue(g)) {
            return; // Successfully added to local queue.
        }

        // Local queue is full, transfer half to global queue.
        self.runqputslow(p, g);
    }

    /// Handle local queue overflow by transferring half to global queue.
    /// Called when both runnext and local queue are full.
    ///
    /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func runqputslow").
    fn runqputslow(self: *schedt, p: *P, new_g: *G) void {
        const BATCH_SIZE: usize = local_queue.RUNQ_SIZE / 2 + 1;

        // Stack-allocated array with compile-time determined size.
        var batch: [BATCH_SIZE]*G = undefined;

        // Calculate how many goroutines to transfer (half of queue).
        const queue_size = p.runq.size();
        const transfer_count = queue_size / 2;

        // Defensive handling: should only be called when local queue is full.
        if (transfer_count == 0) {
            if (self.debug_mode) {
                std.debug.print("Warning: runqputslow called on non-full queue\n", .{});
            }
            // Just put in global queue directly.
            self.globrunqput(new_g);
            return;
        }

        // Extract half of the goroutines from local queue (stack operation, no memory allocation).
        var actual_count: usize = 0;
        var i: usize = 0;
        while (i < transfer_count and actual_count < BATCH_SIZE - 1) : (i += 1) {
            if (p.runq.dequeue()) |gp| {
                batch[actual_count] = gp;
                actual_count += 1;
            } else {
                break; // Queue became empty somehow.
            }
        }

        // half + the incoming new_g.
        batch[actual_count] = new_g;
        actual_count += 1;

        // Create slice pointing to stack array.
        const batch_slice = batch[0..actual_count];

        // Randomize scheduler in debug mode (mimics Go's randomizeScheduler).
        if (self.debug_mode) {
            shuffle.shuffleBatch(*G, batch_slice);
        }

        // Transfer the batch to global queue.
        self.runq.enqueueBatch(batch_slice);

        if (self.debug_mode) {
            std.debug.print("Transferred {} goroutines from P{} to global queue\n", .{ actual_count, p.getID() });
        }
    }

    /// Get the next goroutine to execute from a specific processor.
    /// Prioritizes runnext (fast path) over the main queue.
    /// Returns WorkItem with goroutine and source information.
    ///
    /// Go source: https://github.com/golang/go/blob/master/src/runtime/proc.go (search for "func runqget").
    ///
    /// Implementation Strategy: "Passive Replenishment"
    /// This implementation follows Go's actual strategy of passive runnext replenishment.
    /// When runnext is consumed, it remains empty until a new goroutine is scheduled.
    ///
    /// Alternative Strategy (NOT used): "Active Promotion"
    /// An alternative would be to actively promote a goroutine from runq to runnext
    /// when runnext is consumed, but this approach has drawbacks:
    /// - Increased complexity and potential for bugs
    /// - Additional overhead on every dequeue operation
    /// - May reduce fairness by keeping some goroutines at the back of runq
    /// - Not how Go actually implements it
    ///
    /// Why Passive Replenishment is Better:
    /// - Simpler and more reliable implementation
    /// - runnext serves its intended purpose: fast path for newly created goroutines
    /// - Maintains fairness in goroutine scheduling
    /// - Consistent with Go's design philosophy of simplicity
    /// - New goroutines are created frequently enough that runnext won't stay empty long
    ///
    /// This design choice aligns with Go's runtime implementation and ensures our
    /// educational GMP model accurately reflects the real scheduler behavior.
    pub fn runqget(self: *schedt, p: *P) WorkItem {
        _ = self;

        // Fast path: check runnext first.
        if (p.getRunnext()) |g| {
            p.clearRunnext(); // Clear runnext, no active replenishment.
            return .{ .g = g, .src = .Runnext };
        }

        // Slow path: get from main queue
        const g = p.runq.dequeue();
        return .{ .g = g, .src = .Runq };
    }

    // =====================================================
    // Main Scheduling Loop
    // =====================================================

    /// Main scheduling loop - drives the entire scheduler.
    /// Continuously looks for work and executes goroutines until no work remains.
    pub fn schedule(self: *schedt) void {
        if (self.debug_mode) {
            std.debug.print("=== Scheduler starting with {} processors ===\n", .{self.nproc});
        }

        var round: u32 = 1;

        while (self.hasWork()) {
            if (self.debug_mode) {
                std.debug.print("\n--- Round {} ---\n", .{round});
            }

            var work_done = false;

            // Try to schedule on each processor.
            for (self.processors) |*p| {
                if (self.scheduleOnProcessor(p)) {
                    work_done = true;
                }
            }

            // If no work was done this round, break to avoid infinite loop.
            if (!work_done) {
                if (self.debug_mode) {
                    std.debug.print("No work found, scheduler stopping\n", .{});
                }
                break;
            }

            round += 1;
        }

        if (self.debug_mode) {
            std.debug.print("\nScheduler: All processors idle, scheduling finished\n", .{});

            // Display final status.
            std.debug.print("\n=== Final Status ===\n", .{});
            for (self.processors) |*p| {
                std.debug.print("P{}: {} tasks remaining\n", .{ p.getID(), p.totalGoroutines() });
            }
        }
    }

    /// Check if there's any work to do across all processors and global queue.
    fn hasWork(self: *const schedt) bool {
        // Check if global queue has work.
        if (!self.runq.isEmpty()) return true;

        // Check if any processor has work.
        for (self.processors) |*p| {
            if (p.hasWork()) {
                return true;
            }
        }

        return false;
    }

    /// Try to schedule work on a specific processor.
    /// Returns true if work was done, false if no work available.
    fn scheduleOnProcessor(self: *schedt, p: *P) bool {
        // Try to get work from processor's local queue first.
        const work: WorkItem = self.runqget(p);

        if (work.g) |g| {
            self.logExecStart(p, g, work.src);

            // Execute the goroutine.
            self.executeGoroutine(p, g);

            return true;
        }

        // No local work, try to get from global queue.
        if (!self.runq.isEmpty()) {
            if (self.globrunqget(p, 0)) |g| { // 0 == no extra cap
                self.logExecStart(p, g, .Global);

                // Execute the goroutine.
                self.executeGoroutine(p, g);

                return true;
            } else if (self.debug_mode) {
                std.debug.print("[global] P{} <- batch empty\n", .{p.getID()});
            }
        }

        // No work found for this processor.
        if (self.debug_mode) {
            std.debug.print("[idle]  P{} no work\n", .{p.getID()});
        }

        return false;
    }

    /// Execute a goroutine on a specific processor.
    fn executeGoroutine(self: *schedt, p: *P, g: *G) void {
        // Set processor status.
        p.setStatus(.Running);

        // Execute the goroutine with context.
        const executor = @import("executor.zig");
        executor.execute(g);

        if (self.debug_mode) {
            std.debug.print("P{}: G{} done\n", .{ p.getID(), g.getID() });
        }

        // Clean up the goroutine after execution.
        const lifecycle = @import("lifecycle.zig");
        lifecycle.destroyproc(self, g);

        // Update processor status.
        p.syncStatus();

        // Update idle processor count.
        self.updateIdleCount();
    }

    /// Update the count of idle processors.
    fn updateIdleCount(self: *schedt) void {
        var idle_count: u32 = 0;
        for (self.processors) |*p| {
            if (p.isIdle()) {
                idle_count += 1;
            }
        }
        self.npidle = idle_count;
    }
};
