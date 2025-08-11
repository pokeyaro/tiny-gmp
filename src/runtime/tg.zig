// src/runtime/tg.zig —— runtime internal unified entry

// === runtime core ===
pub const scheduler = @import("core/scheduler/mod.zig");
pub const executor = @import("core/executor.zig");
pub const lifecycle = @import("core/lifecycle.zig");

// === runtime config ===
pub const config = struct {
    pub const scheduler = @import("config/scheduler_config.zig");
};

// === GMP domain ===
pub const gmp = struct {
    pub const goroutine = @import("gmp/goroutine.zig"); // G
    pub const processor = @import("gmp/processor.zig"); // P
};

// === queues ===
pub const queue = struct {
    pub const global_queue = @import("queue/global_queue.zig");
    pub const local_queue = @import("queue/local_queue.zig");
};

// === libs ===
pub const lib = struct {
    pub const algo = struct {
        pub const shuffle = @import("../lib/algo/shuffle.zig");
    };
    pub const ds = struct {
        pub const circular_queue = @import("../lib/ds/circular_queue.zig");
        pub const linkedlist_deque = @import("../lib/ds/linkedlist_deque.zig");
    };
};

// Handy aliases
pub const G = gmp.goroutine.G;
pub const P = gmp.processor.P;
