const std = @import("std");

// =====================================================
// Task Functions
// =====================================================

pub fn task1() void {
    std.debug.print("  -> Hello from task1!\n", .{});
}

pub fn task2() void {
    std.debug.print("  -> Computing 1+1={}\n", .{2});
}

pub fn task3() void {
    std.debug.print("  -> Execute shell `{s}` commands!\n", .{"ls -l"});
}

// Task function array for use by main.zig
pub const TASK_FUNCTIONS = [_](?*const fn () void){ task1, task2, task3 };
