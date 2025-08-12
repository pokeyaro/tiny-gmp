# Go 调度哲学：Idle P 的 LIFO 策略

对于 idle Ps，Go 选择 **last to rest, first to run**。

起初我很疑惑：为什么用单链表？我以为会是一个普通的 FIFO 队列。
从公平性而言，确实 FIFO 更合适。

源码可参考：[runtime/proc.go](https://github.com/golang/go/blob/master/src/runtime/proc.go) （搜索 `func pidleput` 和 `func pidleget`）

## 核心代码

```go
// 入队
pp.link = sched.pidle
sched.pidle.set(pp)

// 出队
pp := sched.pidle.ptr()
sched.pidle = pp.link
```

入队示例：

```text
原链表: idle -> P1 -> P2 -> null
新 P3：P3.link = P1，idle = P3
结果: idle -> P3 -> P1 -> P2 -> null
```

出队示例：

```text
原链表: idle -> P3 -> P1 -> P2 -> null
取出 P3：idle = P1
结果: idle -> P1 -> P2 -> null，返回 P3
```

这明显是用单链表实现的 **栈（LIFO）**：后来的 P 优先被取出。

## 为什么不是 FIFO 或优先队列？

乍看很“资本主义”，但其实是经过权衡的性能优化：

> **一句话版本**：Go 用 LIFO 是为了最大化缓存命中率、减少冷启动开销，而 P idle 本身不需要公平调度，所以牺牲公平性换吞吐量。

### 1. 性能优先

- 单链表头插/头删都是 O(1)
- 不需要遍历或维护尾指针

### 2. 缓存局部性（Cache Locality）

- 刚 idle 下去的 P 里，调度数据、timer heap、mcache 等还在 CPU L1/L2 Cache 和 TLB 中
- 立即复用可以最大化命中率，减少冷启动延迟

### 3. 冷启动代价高

- 如果取一个很久没用的 P（FIFO 尾部），缓存早凉了
- 可能需要重建 timer heap、恢复调度上下文，增加延迟

### 4. 公平性不重要

- P 数量固定，idle 时间短，不存在长时间饥饿问题
- 公平调度主要在 G 层（work stealing、全局 runq），P 层追求性能优先

### 5. 实现简单

- 不需要额外字段或复杂结构
- 避免在 STW 或 sched.lock 下做更多操作

## 对比

| 策略     | 优点               | 缺点                         |
| -------- | ------------------ | ---------------------------- |
| LIFO     | O(1)，缓存热，简单 | 公平性差                     |
| FIFO     | 公平               | 需要 tail 指针，多一次写操作 |
| 优先队列 | 按优先级分配       | O(logP)，实现复杂            |

## 类比现实世界

工厂里的工人休息区：

- **LIFO**：刚坐下的工人马上被叫回去干活，工具还在手里，状态热着
- **FIFO**：最早坐下的工人回去干活，但他已经放下工具，需要重新准备
- **优先队列**：按工人能力或疲劳度分配，但启动慢

Go 选 LIFO，就是 **“好的牛马 🐮🐎” 别走，干活好使就继续用你**。

这，就是 Go 的 **老油条调度哲学**！

---

作者：Pokeya 日期：2025-08-11
