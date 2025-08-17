# Changelog

> **Note**  
> This is a **narrative-style changelog** for a personal/educational project.  
> It does **not** follow the [Keep a Changelog](https://keepachangelog.com/) format, and versioning here is **project-specific**, not strictly [SemVer](https://semver.org/).

---

### v0.8.0 — Safe-Point Preemption

_“The scheduler can now take the wheel.”_

- **Features**: `G` gains `SchedCtx.preempt`; `requestPreempt()` sets flag; `consumePreempt()` checks & clears. Add `YieldReason` for diagnostics.
- **Scheduling**: `executeSlice()` checks preempt before run; tail-enqueue with `runqputTailWithReason`; sampled `g.id % 29 == 0` triggers debug preempt.
- **Goal**: introduce cooperative preemption at call boundaries; remove step counters; pave path for multi-M.

### v0.7.0 — Time-Slice & Yield

_“One step at a time.”_

- **Features**: goroutines now run in deterministic **time-slices (quantum=1)**, with per-G step accounting (`stepsTotal`, `stepsLeft`, `consume`).
- **Scheduling**: unified `runqput` with `to_runnext` **flag**, tail re-enqueue on yield, and fairness preserved across goroutines.
- **Goal**: introduce **cooperative time-slicing** as a foundation for **preemption and multi-M scheduling** in v0.8.

### v0.6.0 — Work-Stealing Arrives

_“Idle Ps now go hunting.”_

- **Features**: randomized victim scan (`cheapRandIndex`); ring traversal skipping self; per-attempt budget (`stealTries × nproc`); capacity-aware skipping via `hasCapacity`; half-batch transfer capped by thief’s available slots; no `runnext` stealing (simpler than Go).
- **Design Boundaries**: single-threaded; no preemption; stealing limited to `.Runq` items; all Ps share a single M.
- **Goal**: enable fair load distribution without preemption; lay the foundation for multi-M and more advanced balancing.

### v0.5.0 — Idle-Aware Wakeups

_“Make sleep/wake first-class.”_

- **Features**: `PStatus {Running, Idle, Parked}`; strict **pidle** push/pop; unified **wakep/tryWake** + **wakeForNewWork** (global enqueue & local overflow); state-driven `schedule()` with early-exit; `displayPidle` debug.
- **Design Boundaries**: single-threaded; no Ms/stealing/preemption; wake only on global work signals.
- **Goal**: correct sleep/wake semantics, lay groundwork for multi-M and work-stealing.

### v0.4.0 — Global Runqueue Online

_“Stable runqueues & batch intake.“_

- **Features**: global runq; batch intake; local overflow to global; debug-first behavior.
- **Design Boundaries**: no work-stealing; no idle-aware wakeups; cooperative (non-preemptive).
- **Goal**: bridge per-P scheduling with system-wide coordination.

### v0.3.0 — Local Runqueues Only + Modular Architecture

_“Per-P scheduling with runnext fast path, no global handoff; refactored into modular files.”_

- **Features**: modular layout (`core/`, `gmp/`, `queue/`, `lib/ds/`); `LocalQueue` on `CircularQueue`; `WorkItem` origin tracing; `assignTasksCustom`; stepwise rounds.
- **Design Boundaries**: no global runq; no work-stealing/wakeups; no preemption/time-slice.
- **Goal**: solidify local-only model; prepare interfaces for global queue.

### v0.2.0 — Per-P Local Runqueues (runnext + circular runq)

_“Multiple Ps with per-P circular queues and a runnext fast path; round-robin assignment; no global queue.”_

- **Features**: P with `runnext` + circular `runq`; round-robin assign; dequeue prioritizes `runnext`; one G per round for traceability.
- **Design Boundaries**: no global runq / batch intake / spill; no work-stealing/wakeups; one-shot tasks.
- **Goal**: establish **per-P semantics** and the **`runnext` fast path**.

### v0.1.0 — Single-Threaded Fixed Queue

_“Single loop over a fixed G array; no P, no queues.“_

- **Features**: fixed `[3]G` one-shot tasks; scan → first `.Ready` → run → `.Done`; one G per cycle.
- **Design Boundaries**: no P; no local/global run queues; no work-stealing.
- **Goal**: establish the **G lifecycle** and the **minimal mental model**.
