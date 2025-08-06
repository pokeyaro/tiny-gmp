# Tiny GMP

A minimal implementation of **Go's GMP scheduler model** in Zig for educational purposes. Learn how **goroutine scheduling** works by building it from scratch.

![Zig](https://img.shields.io/badge/Zig-orange?logo=zig&logoColor=white)
[![Zig Version](https://img.shields.io/badge/Zig-0.14.1-orange.svg)](https://ziglang.org/download/)
![MIT License](https://img.shields.io/badge/License-MIT-blue)
![Educational](https://img.shields.io/badge/Purpose-Educational-green)

## 🚀 Quick Start

Requires [Zig 0.14.1+](https://ziglang.org/download/) (⚠️ Zig syntax changes frequently, please use the exact version):

```bash
git clone https://github.com/pokeyaro/tiny-gmp
cd tiny-gmp
zig build run
```

## 📁 Project Structure

Clean modular architecture with separated concerns:

```bash
src/
├── examples/
│   └── tasks.zig               # Simulated real-world task functions
├── lib/
│   └── ds/
│       └── circular_queue.zig  # Generic circular buffer implementation
├── runtime/
│   ├── core/
│   │   └── scheduler.zig       # Main scheduling logic
│   ├── entity/
│   │   ├── goroutine.zig       # G (Goroutine) implementation
│   │   └── processor.zig       # P (Processor) implementation
│   └── queue/
│       └── local_queue.zig     # Goroutine-specific queue operations
└── main.zig                    # Entry point
```

## ✨ Features

This project implements a **multi-processor scheduler** that demonstrates the core concepts of Go's GMP model:

- **G (Goroutine)**: Task structure with status management and auto-generated IDs

  - Status transitions: `Ready` → `Running` → `Done`

- **P (Processor)**: Local run queues with **runnext optimization**

  - Status transitions: `Idle` ↔ `Running`
  - Implements Go's fast-path scheduling mechanism

## 🎉 What's New in V0.3.0

### 🏗️ Three-Layer Architecture

- **Data Structure Layer** (`lib/ds/`): Pure circular queue implementation
- **Business Logic Layer** (`runtime/queue/`): Goroutine-specific queue operations
- **Entity Layer** (`runtime/entity/`): Processor and Goroutine management

### 🚄 runnext Optimization

Implements Go's actual fast-path scheduling mechanism:

- New goroutines go directly to `runnext` slot
- Fast path: execute `runnext` goroutines immediately
- Slow path: fallback to main queue when `runnext` is empty
- **Passive Replenishment Strategy**: Matches Go's `runqget` implementation

### ✍️ Educational Design

- **Go Source References**: Direct links to Go runtime source code
- **Design Decision Documentation**: Detailed comments explaining implementation choices
- **Source Tracking**: See if goroutines come from `runnext` or `runq`

## 🖥️ Example Output

```text
=== Tiny-GMP V3 ===

=== Initial Assignment ===
P0: next: G5; queue: [G8, G12, G2]
P1: next: G6; queue: [G4, G1, G13]
P2: next: G3; queue: [G11, G9]
P3: next: G0; queue: [G10, G14]
P4: next: G7; queue: []

--- Round 1 ---
P0: Executing G5 (from runnext)
  -> React: Performing virtual DOM diff and re-render
P0: G5 completed

--- Round 2 ---
P0: Executing G8 (from runq)
  -> Database query: `SELECT * FROM users;`
P0: G8 completed

--- Round 3 ---
P0: Executing G12 (from runq)
  -> React: Performing virtual DOM diff and re-render
P0: G12 completed

--- Round 4 ---
P0: Executing G2 (from runq)
  -> Database query: `SELECT * FROM users;`
P0: G2 completed

--- Round 5 ---
P1: Executing G6 (from runnext)
  -> Logging system metrics to Prometheus
P1: G6 completed

--- Round 6 ---
P1: Executing G4 (from runq)
  -> Establishing secure WebSocket connection
P1: G4 completed

--- Round 7 ---
P1: Executing G1 (from runq)
  -> Hello from task1!
P1: G1 completed

--- Round 8 ---
P1: Executing G13 (from runq)
  -> Encrypting file with AES-256
P1: G13 completed

--- Round 9 ---
P2: Executing G3 (from runnext)
  -> Hello from task1!
P2: G3 completed

--- Round 10 ---
P2: Executing G11 (from runq)
  -> Image processing: resize 1920x1080 -> 640x480
P2: G11 completed

--- Round 11 ---
P2: Executing G9 (from runq)
  -> CI/CD: Running e2e tests on staging cluster
P2: G9 completed

--- Round 12 ---
P3: Executing G0 (from runnext)
  -> CI/CD: Running e2e tests on staging cluster
P3: G0 completed

--- Round 13 ---
P3: Executing G10 (from runq)
  -> Vite: Triggering hot module replacement for App.vue
P3: G10 completed

--- Round 14 ---
P3: Executing G14 (from runq)
  -> Logging system metrics to Prometheus
P3: G14 completed

--- Round 15 ---
P4: Executing G7 (from runnext)
  -> Cleaning up temporary cache files
P4: G7 completed

Scheduler: All processors idle, scheduling finished

=== Final Status ===
P0: 0 tasks remaining
P1: 0 tasks remaining
P2: 0 tasks remaining
P3: 0 tasks remaining
P4: 0 tasks remaining
```

## 🛣️ Roadmap

- **V0.1.0**: Basic single-threaded scheduler with fixed goroutine array
- **V0.2.0**: Multi-processor (P) architecture with local run queues
- **v0.3.0**: Major refactor with processor optimization (runnext fast-path slot + runq queue) and clean modular architecture

## 📚 License

MIT License - see [LICENSE](./LICENSE) file for details.

---

_Learn by building. Understand by doing. Master by teaching._
