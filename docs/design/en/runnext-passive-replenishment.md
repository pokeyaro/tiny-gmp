# Go Scheduler Design: The "Runnext" Fast Path & Passive Replenishment

**Tagline:** _One VIP seat, always first in line._

When thinking about Go's scheduler, most people focus on the **local run queue** (`runq`) for each processor (P). But there’s also a special **fast path** — a single-slot VIP channel called **`runnext`**.

---

## What is `runnext`?

All runnable goroutines line up in the local queue like customers in a store. `runnext` is a **dedicated, one-item slot** at the very front:

- **Capacity:** 1 goroutine per P
- **Priority:** Always served **before** anything in `runq`
- **Purpose:** Let a freshly created goroutine run immediately, reducing scheduling latency

**Analogy:** `runnext` is the fast lane at airport security — you skip the entire line.

---

## How `runqget` Works

```zig
pub fn runqget(self: *Self, p: *P) WorkItem {
    // Fast path: check runnext first
    if (p.getRunnext()) |g| {
        p.clearRunnext(); // No active refill
        return .{ .g = g, .src = .Runnext };
    }

    // Slow path: get from normal runq
    const g = p.runq.dequeue();
    return .{ .g = g, .src = .Runq };
}
```

Flow:

1. Check `runnext` — if filled, take it.
2. Otherwise, fall back to `runq`.

---

## The Passive Replenishment Strategy

Go uses **passive replenishment**:

- Once `runnext` is consumed, it **stays empty** until a new goroutine is explicitly put there.
- No automatic promotion from `runq` to `runnext`.

### Why Not Active Promotion?

An alternative would be to _immediately move_ the first `runq` item into `runnext` when it’s empty.

**Drawbacks:**

- More complexity and bug risk
- Extra work on every dequeue
- Hurts fairness — a goroutine could repeatedly jump the line
- Diverges from Go’s real implementation

---

## Why Passive is Better

1. **Simplicity** – Fewer moving parts, fewer bugs.
2. **Purpose Preservation** – Keeps `runnext` for **fresh goroutines**.
3. **Fairness** – Existing `runq` order is respected.
4. **Natural Refill** – In real workloads, `runnext` won’t stay empty long.
5. **Faithfulness** – Matches Go runtime behavior in `proc.go`.

---

## Strategy Comparison

| Strategy              | Pros                                   | Cons                         |
| --------------------- | -------------------------------------- | ---------------------------- |
| Passive Replenishment | Simple, fair, low overhead, matches Go | May be empty briefly         |
| Active Promotion      | Always keeps fast path full            | Complex, less fair, overhead |

---

## Real-World Analogy

Coffee shop with one VIP table:

- **Passive:** Only given to _new VIP arrivals_. If no one qualifies, it stays empty.
- **Active:** Pull someone from the normal line as soon as it’s empty — disrupts order, adds overhead.

Go picks **passive** because it’s clean, fair, and keeps the VIP seat for real VIPs.

---

**Reference:** Go source — `runtime/proc.go`, `runqget`

Author: Pokeya | Date: 2025-08-06
