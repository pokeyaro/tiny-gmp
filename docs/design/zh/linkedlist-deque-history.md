# LinkedListDeque —— 历史设计与内存管理讨论

## 背景

这个基于链表的双端队列最初被设计为 Tiny-GMP 调度器的**全局队列**实现。

它采用了经典的 **Node 包装器 + G 指针** 模式，通过剪切和拼接链表片段来支持批量操作（`dequeueBatch` / `enqueueBatch`）。

虽然双端队列是一个通用且可靠的数据结构，但在 **GMP 全局运行队列** 场景中，它的优势并没有得到充分发挥。同时，额外的复杂性如果没有明确的**所有权定义**，会引入潜在的**内存泄漏风险**。

## 为什么会担心“内存泄漏风险”？

如果没有明确的 **Node 对象所有权协议**，这种双层结构很容易出现“遗弃的盒子”：

```text
GlobalQueue: 拥有 Node 内存，通过 dequeueBatch() 把它交出去
    ↓
TransferBatch（在 tiny-gmp 中叫 `GlobalRunqBatch`）：临时持有 Node 指针，但不拥有它
    ↓
LocalQueue: 将 G 指针提取到 CircularQueue，忽略并丢弃 Node
```

如果**没有任何一方**释放这些 Node 对象，它们会一直留在内存中，最终导致 **OOM**。

## 核心问题

**谁负责释放 Node？**

我们考虑了三种方案：

### 1. 所有权转移（方案 A）

GlobalQueue 将 Node 所有权移交给 LocalQueue，LocalQueue 消费 G 的同时释放 Node 对象。

### 2. 借用 + 提交（方案 B）

LocalQueue _借用_ 这段链表，消费 G 后调用 GlobalQueue 的释放函数来回收 Node。

> **说明**：比方案 A 多一步，但上下文边界更清晰。
>
> 这种模式在 **DDD** 或某些架构风格中也常见，强调严格的所有权边界。如果破坏这种边界（例如 LocalQueue 直接释放 Node），GlobalQueue 会失去对部分生命周期管理的控制。这有点类似 DDD 中的“贫血模型”问题：实体仍然持有数据，但不再封装对应的行为。

### 3. Node 对象池（方案 C）

维护一个专用的 Node 对象池，Global 和 Local 在消费后都将 Node 归还对象池以便复用。

三种方案都通过**明确所有权和释放责任**来消除内存泄漏风险。

## 为什么我们最终没有使用它

1. **Go 已经解决了这个问题** —— 在 Go 的 runtime 中，`g.schedlink` 直接将 goroutine 串起来，不需要额外的 Node 包装。
2. **额外的内存开销** —— 每个 Node 会为每个 G 增加一次结构体分配，以及分配器的额外开销。
3. **不必要的复杂性** —— 在教学中，直接使用 `schedlink` 更贴近 Go 的真实实现，而且更轻量。

## 当前状态

这个文件保留为一个**高质量的通用双端队列实现**，用于教学，展示设计迭代和权衡。但在调度器本身中它已被**弃用**。

另见：[linkedlist_deque.zig](../../src/lib/ds/linkedlist_deque.zig)

---

作者：Pokeya 日期：2025-08-08
