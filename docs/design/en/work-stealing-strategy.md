# Go Scheduler Design: Work-Stealing — Let Idle Ps Take Initiative

## Background

In multi-processor (P) scheduling, if a P's local queue runs out of tasks, it becomes idle. This can reduce overall system throughput: some Ps are overloaded while others do nothing.

The philosophy of **work-stealing** is:

> "Don’t wait for work to come to you — go find it."

This way, an idle P can proactively take some tasks from busy Ps, balancing the workload.

## Core Principles

- **Proactivity**: An idle P doesn’t rely on global signals but periodically scans potential "victims".
- **Limits**: Not endless scanning — there are **budgets** and **rules** to avoid wasting resources.
- **Non-violent stealing**: Never empties the victim entirely — takes only half, leaving them with work.
- **Skip the "VIP"**: High-priority temporary tasks (like `runnext`) are off-limits, reducing interference.

## Victim Scanning Philosophy

1. **Randomized Start Point**

   - Fixed order can make some Ps perpetual "victims", which is unfair.
   - Randomized start distributes stealing targets more evenly.

2. **Ring Scan**

   - From the start point, traverse Ps in a circular (ring) fashion.
   - Skip self (the thief) to avoid self-stealing.

3. **Multi-Round Budget (steal budget)**

   - To prevent infinite spinning, we set a budget: `stealTries × nproc`.
   - Each victim scanned consumes budget.
   - Multiple rounds help catch newly queued tasks after the first round.

4. **No `runnext` Stealing**

   - **Design choice**: do not steal from victim’s `runnext`, simplifying logic.
   - `runnext` tasks are typically just-created, high-priority Gs — let the victim handle them.

## How Much to Steal?

- **Half-Batch Steal**:

  - Theoretical steal amount = `victim.runq.size / 2` (floor).
  - Enough to keep the idle P busy while reducing frequent steals.
  - Ensures victim still has work.

- **Capacity Limit**:

  - Do not exceed thief’s remaining local queue capacity.
  - Avoid "bringing home more than you can store".

## Why This Matters

- **Balances throughput**: Keeps all Ps busy, reduces idle time.
- **Reduces latency**: Lowers the chance a task is stuck on an overloaded P.
- **Improves user experience**: Tasks finish sooner, better resource utilization.

---

Author: Pokeya | Date: 2025-08-15
