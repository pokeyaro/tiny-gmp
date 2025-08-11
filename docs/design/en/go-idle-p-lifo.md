# Go Scheduler Philosophy: Idle P’s LIFO Strategy

**Tagline:** _last to rest, first to run._

At first, I was puzzled: why a singly linked list? I expected a simple FIFO queue for fairness. From a fairness standpoint, FIFO sounds more reasonable.

Source reference: [runtime/proc.go](https://github.com/golang/go/blob/master/src/runtime/proc.go) (search for `func pidleput` and `func pidleget`).

## Core Code

```go
// Push (pidleput)
pp.link = sched.pidle
sched.pidle.set(pp)

// Pop (pidleget)
pp := sched.pidle.ptr()
sched.pidle = pp.link
```

Push example:

```
Original: idle -> P1 -> P2 -> null
New P3: P3.link = P1, idle = P3
Result: idle -> P3 -> P1 -> P2 -> null
```

Pop example:

```
Original: idle -> P3 -> P1 -> P2 -> null
Take P3: idle = P1
Result: idle -> P1 -> P2 -> null, return P3
```

Clearly, this is a stack (LIFO) implemented as a singly linked list: the most recently added P is retrieved first.

## Why not FIFO or a Priority Queue?

It might seem counterintuitive at first, but this is an intentional performance optimization:

> **In one sentence:** Go uses LIFO to maximize cache locality and reduce cold-start overhead. Since fairness isn’t critical for idle Ps, the scheduler trades fairness for throughput.

### 1. Performance First

- Singly linked list head push/pop are O(1)
- No traversal or tail maintenance needed

### 2. Cache Locality

- A recently idled P still has scheduler data, timer heap, mcache, etc., in L1/L2 cache and TLB
- Reusing it immediately maximizes cache hit rate and minimizes wake-up latency

### 3. Cold-Start Cost

- Taking a long-idle P (FIFO tail) means caches are cold
- May require rebuilding timer heap and restoring scheduler state, increasing latency

### 4. Fairness Not Critical

- P count is fixed, idle time is short, starvation isn’t a real concern
- Fairness is enforced at the goroutine level (work stealing, global runq)

### 5. Implementation Simplicity

- No extra fields or complex data structures
- Less work inside `sched.lock` or STW periods

## Comparison Table

| Strategy   | Pros                          | Cons                             |
| ---------- | ----------------------------- | -------------------------------- |
| LIFO       | O(1), hot cache reuse, simple | Less fair                        |
| FIFO       | Fair rotation                 | Needs tail pointer, extra writes |
| Priority Q | Policy-based ordering         | O(logP), overkill                |

## Real-World Analogy

Imagine a break room in a factory:

- **LIFO:** The worker who just sat down is called back immediately — tools still in hand, fully warmed up
- **FIFO:** The worker who’s been resting the longest returns — but has to grab tools and get back into rhythm
- **Priority Queue:** Assigns tasks based on skill or fatigue — but slower to decide

Go picks LIFO because **it’s about getting the most ready worker back on the job instantly**.

This is Go’s _street-smart scheduler philosophy_ — fast over fair when fairness doesn’t matter.

---

Author: Pokeya | Date: 2025-08-11
