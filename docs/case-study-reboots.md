# 案例：官方 5.10.136 内核的随机重启分析（脱敏）

本案例记录两台（同一机型/同一 ROM 版本）目标设备在 2026-09-25 与
2026-09-26 出现的两次内核级重启，用于说明 CVE-2026-43499 的实际表现。

> 已删除序列号、IMEI、手机号、个人应用列表、隐藏 Magisk 包名等敏感信息。

## 环境

- Redmi Note 12T Pro（`pearl`，MT6895）
- MIUI 14 / `V14.0.5.0.TLHCNXM` / Android 13
- 官方内核 `5.10.136-android12-9-00020-gc9f59ef34367-ab9585114`
- bootloader 已解锁，使用 Magisk + Zygisk/LSPosed 生态（与本问题无直接因果关系）
- 未充电
- 未运行 VPN/代理类应用（第二次）

## 案例一：2026-09-25 19:08（直接 Oops）

`ro.boot.bootreason` 与 AEE 均记录 `kernel_panic`。ramoops 中的关键信息：

```text
Unable to handle kernel paging request at virtual address 0000000100000037
Internal error: Oops: 96000021 [#1] PREEMPT SMP
CPU: 6 PID: 1975 Comm: ReferenceQueueD
Tainted: P        WC O

Call trace:
 put_pi_state+0x34/0x390
 futex_requeue+0x1128/0x15b8
 do_futex+0x168/0x33c
 __arm64_sys_futex+0xb0/0x2b8
 el0_svc_common...
```

`futex_requeue → put_pi_state` 正是 CVE-2026-43499 描述的 PI futex
回滚路径。当天有使用 Go runtime 网络应用的记录，Go runtime 的高频 futex
操作可作为触发器，但不是根因。

## 案例二：2026-09-26 17:34（挂死 → 冷复位）

- 通话建立过程中，内核在配置通话音频通路（PCM/听筒音量）后**停止输出**；
- `console-ramoops` 最后一条日志为 `mt6368_put_volsw(), name Handset Volume`；
- 之后约 46 秒无任何内核输出，AEE 记录 `KE`，`poffreason=Cold_reset`；
- 没有 panic 文本，属于挂死型异常；
- 事后检查：未充电（`vbus=0`、discharging）、未运行 VPN/代理应用。

由于 UAF 会造成内存损坏，第二次崩溃点落在通话音频/ADSP 路径并不矛盾：
损坏后的崩溃位置可以是任意后续使用该内存的路径。

## 结论

- 两次重启都发生在**缺少 CVE-2026-43499 修复的官方 5.10.136 内核**上；
- 第一次的调用栈与 CVE 完全吻合，第二次的挂死符合同一类内存损坏的表现；
- 解锁 BL / Magisk 不是根因（内核二进制未改变，仅 ramdisk 被修改）；
- 修复方式：应用 5.10.260 的两个 backport，重新编译内核；
- 刷入修复内核后，`remove_waiter()` 不再读取 `current`，需继续观察是否仍有
  新的 `kernel_panic`；如果还有，应按 `docs/verification.md` 采集证据，作为
  独立问题分析。
