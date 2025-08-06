const std = @import("std");
const scheduler = @import("runtime/core/scheduler.zig");

// =====================================================
// Main Entry Point
// =====================================================

pub fn main() !void {
    try scheduler.run();
}
