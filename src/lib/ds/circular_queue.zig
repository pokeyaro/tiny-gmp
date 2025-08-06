const std = @import("std");

// =====================================================
// Generic Circular Queue Data Structure
// =====================================================

/// Generic circular queue implementation that can store any type T.
/// Uses a compile-time size parameter for zero-runtime-cost abstraction.
///
/// Reference: Classic circular buffer algorithm from "Introduction to Algorithms" (CLRS)
/// See also: https://en.wikipedia.org/wiki/Circular_buffer
///
/// **Important**: This is a fixed-capacity queue and does not support dynamic resizing.
///
/// Implementation Details:
/// - Uses head/tail pointers to track queue boundaries
/// - Reserves one buffer slot internally to distinguish between full and empty states
/// - Circular indexing with modulo arithmetic for efficient wraparound
///
/// Time Complexity:
/// - enqueue/dequeue: O(1)
/// - front/back peek: O(1)
/// - size/isEmpty/isFull: O(1)
/// - iterate: O(n)
pub fn CircularQueue(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();
        const BUFFER_SLOT = 1; // Reserve one slot to distinguish full from empty
        const INTERNAL_CAPACITY = capacity + BUFFER_SLOT;

        buffer: [INTERNAL_CAPACITY]?T,
        head: usize = 0,
        tail: usize = 0,

        /// Initialize a new empty circular queue.
        pub fn init() Self {
            return Self{
                .buffer = [_]?T{null} ** INTERNAL_CAPACITY,
                .head = 0,
                .tail = 0,
            };
        }

        /// Get the number of elements currently in the queue.
        pub fn size(self: *const Self) usize {
            return (self.tail - self.head) % INTERNAL_CAPACITY;
        }

        /// Get the maximum capacity of the queue.
        pub fn maxCapacity() usize {
            return capacity;
        }

        /// Check if the queue is empty.
        pub fn isEmpty(self: *const Self) bool {
            return self.size() == 0;
        }

        /// Check if the queue is full.
        pub fn isFull(self: *const Self) bool {
            return self.size() >= capacity;
        }

        /// Add an element to the back of the queue.
        /// Returns true if successful, false if the queue is full.
        pub fn enqueue(self: *Self, item: T) bool {
            if (self.isFull()) {
                return false;
            }

            self.buffer[self.tail % INTERNAL_CAPACITY] = item;
            self.tail += 1;
            return true;
        }

        /// Remove and return an element from the front of the queue.
        /// Returns null if the queue is empty.
        pub fn dequeue(self: *Self) ?T {
            if (self.isEmpty()) {
                return null;
            }

            const item = self.buffer[self.head % INTERNAL_CAPACITY];
            self.buffer[self.head % INTERNAL_CAPACITY] = null;
            self.head += 1;
            return item;
        }

        /// Peek at the front element without removing it.
        /// Returns null if the queue is empty.
        pub fn front(self: *const Self) ?T {
            if (self.isEmpty()) {
                return null;
            }
            return self.buffer[self.head % INTERNAL_CAPACITY];
        }

        /// Peek at the back element without removing it.
        /// Returns null if the queue is empty.
        pub fn back(self: *const Self) ?T {
            if (self.isEmpty()) {
                return null;
            }
            const back_index = if (self.tail == 0) INTERNAL_CAPACITY - 1 else (self.tail - 1) % INTERNAL_CAPACITY;
            return self.buffer[back_index];
        }

        /// Clear all elements from the queue.
        pub fn clear(self: *Self) void {
            self.buffer = [_]?T{null} ** INTERNAL_CAPACITY;
            self.head = 0;
            self.tail = 0;
        }

        /// Iterate over all elements in the queue from front to back.
        /// The callback function receives each element.
        pub fn iterate(self: *const Self, callback: fn (T) void) void {
            var i = self.head;
            while (i != self.tail) {
                if (self.buffer[i % INTERNAL_CAPACITY]) |item| {
                    callback(item);
                }
                i += 1;
            }
        }

        /// Iterate over all elements with context.
        /// The callback function receives (context, element).
        pub fn iterateWithCtx(self: *const Self, context: anytype, callback: fn (@TypeOf(context), T) void) void {
            var i = self.head;
            while (i != self.tail) {
                if (self.buffer[i % INTERNAL_CAPACITY]) |item| {
                    callback(context, item);
                }
                i += 1;
            }
        }
    };
}
