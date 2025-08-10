# LinkedListDeque — Historical Design & Memory Management Discussion

## Background

This linked-list-based deque was originally designed as the **global queue** implementation for Tiny-GMP's scheduler.

It used a classic **Node wrapper + G pointer** pattern, allowing batch operations (`dequeueBatch` / `enqueueBatch`) to be performed
by cutting and splicing linked segments.

While a doubly-ended queue is a solid, general-purpose data structure, in the context of a **GMP global run queue**, its strengths are not fully utilized.
Moreover, the added complexity introduces potential **memory leak risks** if ownership is not clearly defined.

## Why the "Memory Leak Risk" Concern?

Without a clear **ownership protocol** for Node objects, the dual-layer structure can easily lead to “abandoned boxes”:

```text
GlobalQueue: owns Node memory, gives it away via dequeueBatch()
    ↓
TransferBatch (`GlobalRunqBatch` in tiny-gmp): temporary holder of Node pointers, no ownership
    ↓
LocalQueue: extracts G pointers into CircularQueue, ignores and discards Nodes
```

If **no party** frees these Node objects, they remain in memory indefinitely, eventually leading to **OOM**.

## Core Question

**Who is responsible for freeing Node?**

We considered three approaches:

### 1. Ownership Transfer (Option A)

GlobalQueue hands over Node ownership to LocalQueue.  
LocalQueue consumes G while freeing the Node objects.

### 2. Borrow + Commit (Option B)

LocalQueue _borrows_ the segment, consumes G, then calls GlobalQueue’s release function to free Nodes.

> **Note**: Slightly more “two-step” than Option A, but keeps context boundaries explicit.
>
> This pattern is also seen in **DDD** or certain architecture styles where strict ownership boundaries matter.  
> If this boundary is violated — e.g., LocalQueue directly frees Node — GlobalQueue loses control over part of its own lifecycle management.  
> This is somewhat analogous to the “anemic model” problem in DDD, where an entity still holds data but no longer encapsulates its corresponding behavior.

### 3. Node Pool (Option C)

Maintain a dedicated Node object pool.  
Both Global and Local return Nodes to the pool after consumption for reuse.

All three options eliminate the leak by **defining ownership and disposal responsibility**.

## Why We Didn’t Use It

1. **Go already solves this** — In Go’s runtime, `g.schedlink` directly chains goroutines; no extra Node wrapper is needed.
2. **Extra memory cost** — Each Node adds another struct allocation per G, plus allocator overhead.
3. **Unnecessary complexity** — For educational purposes, using `schedlink` is closer to Go’s real implementation and is lighter.

## Current Status

This file remains as a **high-quality, generic deque** for educational purposes, showcasing design iteration and trade-offs,
but it is **deprecated** in the scheduler itself.

See also: [`linkedlist_deque.zig`](../../src/lib/ds/linkedlist_deque.zig)
