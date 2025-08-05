# Tiny GMP

A minimal implementation of Go's GMP scheduler model in Zig for educational purposes. Learn how goroutine scheduling works by building it from scratch.

## 🚀 Quick Start

```bash
git clone https://github.com/pokeyaro/tiny-gmp
cd tiny-gmp
zig build run
```

## 👀 Current Status

This project implements a **multi-processor scheduler** that demonstrates the core concepts of Go's GMP model:

- **G** (Goroutine): Task structure with status management and auto-generated IDs
- **P** (Processor): Local run queues with circular buffer implementation and `runnext` optimization
- **Scheduling Logic**: Round-robin execution across multiple processors
- **Status Transitions**: `Ready` → `Running` → `Done`

## 🖥️ Example Output

```text
=== Tiny-GMP V2 ===

=== Initial Assignment ===
P0: [G0, G4, G8]
P1: [G1, G5, G9]
P2: [G2, G6]
P3: [G3, G7]

--- Round 1 ---
P0: Executing G0
  -> Hello from task1!
P0: G0 completed

--- Round 2 ---
P0: Executing G4
  -> Computing 1+1=2
P0: G4 completed

--- Round 3 ---
P0: Executing G8
  -> Execute shell `ls -l` commands!
P0: G8 completed

--- Round 4 ---
P1: Executing G1
  -> Computing 1+1=2
P1: G1 completed

--- Round 5 ---
P1: Executing G5
  -> Execute shell `ls -l` commands!
P1: G5 completed

--- Round 6 ---
P1: Executing G9
  -> Hello from task1!
P1: G9 completed

--- Round 7 ---
P2: Executing G2
  -> Execute shell `ls -l` commands!
P2: G2 completed

--- Round 8 ---
P2: Executing G6
  -> Hello from task1!
P2: G6 completed

--- Round 9 ---
P3: Executing G3
  -> Hello from task1!
P3: G3 completed

--- Round 10 ---
P3: Executing G7
  -> Computing 1+1=2
P3: G7 completed

--- Round 11 ---
Scheduler: All processors idle, scheduling finished

=== Final Status ===
P0: 0 tasks remaining
P1: 0 tasks remaining
P2: 0 tasks remaining
P3: 0 tasks remaining
```

## 🛣️ Roadmap

- **V0.1.0**: Basic single-threaded scheduler with fixed goroutine array
- **V0.2.0**: Multi-processor (P) architecture with local run queues

## 📚 License

MIT License - see [LICENSE](./LICENSE) file for details.
