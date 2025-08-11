//! Generic linked-list deque data structure
//!
//! Dynamic-capacity double-ended queue with O(1) push/pop at both ends,
//! allocator-backed nodes, and bidirectional iteration for flexible buffering.
//! Preserved as a general-purpose utility; not used by the scheduler (historical).
//! See docs/design/en/linkedlist-deque-history.md for background.

const std = @import("std");

// =====================================================
// Generic LinkedList-based Deque Data Structure
// =====================================================

/// Generic doubly-linked list based deque implementation.
/// Supports efficient insertion and removal from both ends.
///
/// Reference: Classic doubly-linked list algorithm from "Introduction to Algorithms" (CLRS)
/// See also: https://en.wikipedia.org/wiki/Double-ended_queue
///
/// **Important**: This is a dynamic-capacity deque with no size limits.
///
/// Implementation Details:
/// - Uses head/tail pointers for O(1) front/back operations
/// - Doubly-linked nodes for bidirectional traversal
/// - Dynamic memory allocation for unlimited capacity
/// - Memory efficient for sparse usage patterns
///
/// Time Complexity:
/// - pushFront/pushBack: O(1)
/// - popFront/popBack: O(1)
/// - front/back: O(1)
/// - size: O(n)
/// - isEmpty: O(1)
/// - clear: O(n)
pub fn LinkedListDeque(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Node structure for the doubly-linked list.
        const Node = struct {
            data: T,
            next: ?*Node = null,
            prev: ?*Node = null,

            /// Create a new node with the given data.
            fn init(data: T) Node {
                return Node{
                    .data = data,
                    .next = null,
                    .prev = null,
                };
            }
        };

        head: ?*Node = null,
        tail: ?*Node = null,
        allocator: std.mem.Allocator,

        /// Initialize a new empty deque with the given allocator.
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .head = null,
                .tail = null,
                .allocator = allocator,
            };
        }

        /// Deallocate all nodes and clear the deque.
        /// Alias for clear() following Zig's deinit convention for lifecycle management.
        pub fn deinit(self: *Self) void {
            self.clear();
        }

        /// Check if the deque is empty.
        pub fn isEmpty(self: *const Self) bool {
            return self.head == null;
        }

        /// Get the number of elements in the deque (O(n) operation).
        /// Note: This requires traversal, use sparingly in performance-critical code.
        ///
        /// Design Decision: We deliberately choose O(n) size over maintaining a counter field
        /// to keep the data structure simple and memory-efficient.
        pub fn size(self: *const Self) usize {
            var count: usize = 0;
            var current = self.head;
            while (current) |node| {
                count += 1;
                current = node.next;
            }
            return count;
        }

        /// Add an element to the front of the deque.
        /// Returns true if successful, false if memory allocation fails.
        pub fn pushFront(self: *Self, item: T) !void {
            const new_node = try self.allocator.create(Node);
            new_node.* = Node.init(item);
            if (self.head) |head| {
                new_node.next = head;
                head.prev = new_node;
                self.head = new_node;
            } else {
                // Empty deque.
                self.head = new_node;
                self.tail = new_node;
            }
        }

        /// Add an element to the back of the deque.
        /// Returns true if successful, false if memory allocation fails.
        pub fn pushBack(self: *Self, item: T) !void {
            const new_node = try self.allocator.create(Node);
            new_node.* = Node.init(item);

            if (self.tail) |tail| {
                tail.next = new_node;
                new_node.prev = tail;
                self.tail = new_node;
            } else {
                // Empty deque
                self.head = new_node;
                self.tail = new_node;
            }
        }

        /// Remove and return an element from the front of the deque.
        /// Returns null if the deque is empty.
        pub fn popFront(self: *Self) ?T {
            const head = self.head orelse return null;
            const data = head.data;

            if (head.next) |next| {
                next.prev = null;
                self.head = next;
            } else {
                // Only one element, deque becomes empty.
                self.head = null;
                self.tail = null;
            }

            self.allocator.destroy(head);
            return data;
        }

        /// Remove and return an element from the back of the deque.
        /// Returns null if the deque is empty.
        pub fn popBack(self: *Self) ?T {
            const tail = self.tail orelse return null;
            const data = tail.data;

            if (tail.prev) |prev| {
                prev.next = null;
                self.tail = prev;
            } else {
                // Only one element, deque becomes empty.
                self.head = null;
                self.tail = null;
            }

            self.allocator.destroy(tail);
            return data;
        }

        /// Peek at the front element without removing it.
        /// Returns null if the deque is empty.
        pub fn front(self: *const Self) ?T {
            return if (self.head) |head| head.data else null;
        }

        /// Peek at the back element without removing it.
        /// Returns null if the deque is empty.
        pub fn back(self: *const Self) ?T {
            return if (self.tail) |tail| tail.data else null;
        }

        /// Remove all elements from the deque and deallocate memory.
        pub fn clear(self: *Self) void {
            while (self.popFront()) |_| {
                // popFront handles deallocation.
            }
        }

        /// Iterate over all elements from front to back.
        /// The callback function receives each element.
        pub fn iterate(self: *const Self, callback: fn (T) void) void {
            var current = self.head;
            while (current) |node| {
                callback(node.data);
                current = node.next;
            }
        }
    };
}
