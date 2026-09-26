# CVE-2026-43499 根因说明

## 一句话

官方 5.10.136 内核的 `kernel/locking/rtmutex.c` 中，`remove_waiter()` 在
`rt_mutex_start_proxy_lock()` 的回滚路径里使用了 `current`，但此时 waiter
属于另一个任务。正确做法是使用 `waiter->task`。错误写法会留下悬空的
`pi_blocked_on` 指针，形成 use-after-free（UAF），可被 PI futex 的
`futex_requeue()` 路径触发。

## 漏洞代码（修复前）

```c
static void remove_waiter(struct rt_mutex *lock,
                          struct rt_mutex_waiter *waiter)
{
    ...
    raw_spin_lock(&current->pi_lock);
    rt_mutex_dequeue(lock, waiter);
    current->pi_blocked_on = NULL;
    raw_spin_unlock(&current->pi_lock);
    ...
    rt_mutex_adjust_prio_chain(owner, RT_MUTEX_MIN_CHAINWALK, lock,
                               next_lock, NULL, current);
}
```

在 `rt_mutex_start_proxy_lock()` / `rt_mutex_cleanup_proxy_lock()` 被
`futex_requeue()` 调用时，`current` 与 `waiter->task` **不是同一个任务**。
后果：

1. 在未持有 `waiter->task->pi_lock` 的情况下操作 rbtree；
2. `waiter->task->pi_blocked_on` 没有被清空，留下悬空指针（UAF）；
3. `rt_mutex_adjust_prio_chain()` 操作了错误的任务。

## 修复（官方 5.10.260 backport）

```c
struct task_struct *waiter_task = waiter->task;

if (!waiter_task) /* never enqueued */
    return;

raw_spin_lock(&waiter_task->pi_lock);
rt_mutex_dequeue(lock, waiter);
waiter_task->pi_blocked_on = NULL;
raw_spin_unlock(&waiter_task->pi_lock);
...
rt_mutex_adjust_prio_chain(owner, RT_MUTEX_MIN_CHAINWALK, lock,
                           next_lock, NULL, waiter_task);
```

同时收紧 `rt_mutex_start_proxy_lock()` 的回滚条件，只在 `ret < 0` 时调用
`remove_waiter()`。

- mainline 修复：`3bfdc63936dd4773109b7b8c280c0f3b5ae7d349`（2026-04-21）
- 5.10 backport：`f3fa3424bceb128d2be4b3745506b22844b87db7` +
  `bfbc047ceb42c0e1fac8f3a155d4548a8bbe76b1`（Linux 5.10.260，2026-07-24）

本仓库的 `patches/` 目录按顺序包含这两个 backport。

## 为什么会出现“各种地方都在崩”

UAF 造成的是内核内存损坏。损坏发生后，崩溃点可以是任何后续访问该内存的
路径，例如 futex PI 链、调度器、zram、缺页处理、音频/通话路径等。因此不能
因为崩溃函数不同就排除同一个根因。

## 为什么不是 Magisk / 解锁 BL

- 解锁 BL 本身不修改内核代码；
- Magisk 的主要机制是修改 boot 镜像里的 **ramdisk**，注入 root；
- 对目标设备做过的对比显示：Magisk 修补后的 `boot_a` 与未修补的 `boot_b`，
  其内核二进制区段 SHA256 完全一致，只有 ramdisk 不同。

Root 应用（尤其是使用 PI futex 的 Go runtime 网络应用）可能提高触发概率，
但漏洞本身在官方内核里，属于“触发器”和“根因”的区别。

## 引用

- NVD: https://nvd.nist.gov/vuln/detail/CVE-2026-43499
- mainline commit:
  https://github.com/torvalds/linux/commit/3bfdc63936dd4773109b7b8c280c0f3b5ae7d349
- 5.10 backport 1:
  https://github.com/gregkh/linux/commit/f3fa3424bceb128d2be4b3745506b22844b87db7
- 5.10 backport 2:
  https://github.com/gregkh/linux/commit/bfbc047ceb42c0e1fac8f3a155d4548a8bbe76b1
- Xiaomi kernel source:
  https://github.com/MiCode/Xiaomi_Kernel_OpenSource/tree/pearl-s-oss
