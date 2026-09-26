# redmi-note-12t-pro-kernel

[English](README.md) | **简体中文**

Redmi Note 12T Pro（codename `pearl`，MediaTek MT6895/MT6896）**非官方内核补丁、安全修复与工具集**。当前重点是修复官方 MIUI 14 / 5.10.136 内核的 **CVE-2026-43499**；后续可以继续追加该机型的其它内核 CVE、补丁、配置以及构建/验证工具。

> **免责声明**：本项目与小米/Redmi 官方无关。刷入内核有风险；仅适用于 `pearl` 机型 + 匹配的 ROM/内核版本。刷入前必须备份 boot 分区，风险自负。

## 当前包含的修复

| 修复 | 补丁 | 状态 |
|---|---|---|
| CVE-2026-43499：`rtmutex` `remove_waiter()` UAF | 官方 5.10.260 backport `f3fa3424` + `bfbc047c` | 已提供补丁、构建、验证与回滚流程 |

> 新增修复时的约定：补丁放入 `patches/`（编号递增），在本文档和 `CHANGELOG.md` 追加条目，并在对应的 GitHub Release 中附带构建产物、SHA256 和适用条件。

## 背景：这是什么问题

- **受影响环境**：官方 MIUI `V14.0.5.0.TLHCNXM`，Android 13，内核 `5.10.136`（2023-02-08 构建）。
- **漏洞位置**：`kernel/locking/rtmutex.c` 的 `remove_waiter()`。
  它在 `rt_mutex_start_proxy_lock()` 的回滚路径中错误地使用 `current`，而正确对象是 `waiter->task`。
  这会留下悬空的 `pi_blocked_on` 指针，属于 use-after-free（UAF）。
- **触发路径**：PI futex / `FUTEX_CMP_REQUEUE_PI` 等涉及 `futex_requeue()` 的场景。
  Go runtime 的网络应用、系统服务、通话/音频等都可能产生相关调用。
- **可能表现**：
  - 直接 Oops：`futex_requeue → put_pi_state`；
  - 通话/音频建立过程中内核挂死，随后冷复位；
  - 由于是内存损坏，也可能在其他子系统出现看似不相关的随机 panic。
- **上游修复**：
  - mainline `3bfdc63936dd`（2026-04-21）
  - 5.10 稳定版 backport：`f3fa3424` + `bfbc047c`，随 **Linux 5.10.260**（2026-07）发布
- **与解锁 BL / Magisk 的关系**：
  解锁 BL 本身不修改内核；Magisk 只修补 boot 的 ramdisk。对目标设备的对比确认，Magisk 修补前后的内核二进制区段完全一致。
  Root/Go 应用只是可能提高触发概率，不是漏洞根因。

## 仓库结构

```text
.
├── README.md                          # 英文（默认）
├── README.zh-CN.md                    # 中文
├── configs/device_kconfig.txt          # 目标设备 /proc/config.gz 导出的内核配置
├── docs/
│   ├── root-cause.md                    # 漏洞原理与引用
│   ├── build-guide.md                   # 编译 + 打包完整步骤
│   ├── verification.md                  # 刷前/刷后验证
│   ├── rollback.md                      # 备份与回滚
│   ├── case-study-reboots.md            # 脱敏的重启案例分析
│   ├── device-reference.md              # 设备/ROM/内核信息（无序列号）
│   └── release-process.md               # 自动发布 Release 说明
├── patches/
│   ├── 0001-rtmutex-use-waiter-task-in-remove_waiter.patch
│   └── 0002-rtmutex-skip-remove_waiter-when-not-enqueued.patch
├── scripts/
│   ├── build-kernel.sh                  # 辅助编译脚本
│   ├── pack-boot.sh                     # 用 magiskboot 替换内核并保留 ramdisk
│   └── prepare-release-assets.sh        # 生成 Release 资产与校验和
├── tools/
│   ├── check_kernel.sh                  # 检测内核是否包含修复
│   ├── ghostlock-extract                # 上游检测器（macOS arm64 便利二进制）
│   ├── module-crc-check.py              # vendor 模块 CRC 兼容性校验
│   └── README.md
└── .github/workflows/
    ├── patch-check.yml                  # CI：补丁可干净应用
    └── release.yml                      # CI：打 tag 自动构建并发布 Release
```

## 快速开始

### 1. 检测当前设备内核

```bash
tools/check_kernel.sh
```

- 需要已 root 的 adb（Magisk/KernelSU 授权 `su`）。
- 只读操作，不会向手机写入文件。
- 输出「已修复」才说明 `remove_waiter()` 不再读取 `current`。

也可以检测指定 boot 镜像：

```bash
tools/check_kernel.sh /path/to/boot.img
```

### 2. 编译修复内核

见 [`docs/build-guide.md`](docs/build-guide.md)。核心步骤：

1. 获取官方源码 `pearl-s-oss`，提交 `d96c1a04b701bcf1d39ed1b8ab4b3137ff6490f9`（5.10.136）；
2. 按顺序应用 `patches/` 下的两个官方 5.10.260 backport；
3. 使用 `configs/device_kconfig.txt` 作为基线配置；
4. 用 clang 12 + LLVM/LLD 编译 `Image` / `Image.gz`（x86_64 构建机上脚本会自动设置 `CROSS_COMPILE=aarch64-linux-gnu-`）；
5. 用 `magiskboot` 把新 `Image` 替换进原 boot 镜像，保留 Magisk ramdisk；
6. 用 `tools/check_kernel.sh` 验证新 boot 镜像，再进行刷入。

### 3. 验证与回滚

- [`docs/verification.md`](docs/verification.md)：刷前 / 刷后检查清单。
- [`docs/rollback.md`](docs/rollback.md)：boot 分区备份、fastboot 回滚、root `dd` 回滚。
- **刷机前务必保存原 boot 分区**；本仓库不包含任何设备唯一分区备份。

## 自动发布 Release（方便下载）

仓库包含 [`.github/workflows/release.yml`](.github/workflows/release.yml)：

- 推送 `v*` 标签（例如 `v1.0.0-cve-2026-43499`）会触发 GitHub Actions：
  1. 下载固定提交的官方 `pearl-s-oss` 源码；
  2. 应用本仓库两个补丁；
  3. 使用 ThinLTO + CFI + Shadow Call Stack + MODVERSIONS 构建；
  4. 用上游 GhostLock 检测器验证 `remove_waiter()` 修复；
  5. 发布 GitHub Release 并附上校验和。
- Release 资产（kernel-only）：
  - `redmi-note-12t-pro-kernel-<tag>-Image.gz`
  - `redmi-note-12t-pro-kernel-<tag>-Image`
  - `redmi-note-12t-pro-kernel-<tag>-Module.symvers`
  - `redmi-note-12t-pro-kernel-<tag>-device_kconfig.patched`
  - `build-info.txt`
  - `SHA256SUMS`
- **重要**：自动 Release **不包含可直接 fastboot 刷入的 boot.img**。boot 镜像还包含与 ROM/Magisk 相关的 ramdisk；请用你自己的 boot 备份 + [`scripts/pack-boot.sh`](scripts/pack-boot.sh) 打包。详见 [`docs/release-process.md`](docs/release-process.md)。

触发第一个 Release：

```bash
git tag v1.0.0-cve-2026-43499
git push origin v1.0.0-cve-2026-43499
```

## 已验证结果（目标设备）

- 编译产物运行版本：`5.10.136-pearl-cve43499`
- `tools/check_kernel.sh`：`remove_waiter()` 不再读取 `current` → **已修复**
- vendor 模块 CRC 全量校验：228 个模块、13,118 个符号引用，**11,397 匹配 / 0 不匹配**
- 刷后功能：Magisk root、Wi-Fi、蓝牙、触摸、相机（5 路）、指纹 HAL、GPS、音频、Telephony 均正常

> 说明：为避免低内存环境 FULL LTO 链接 OOM，验证构建使用了 **ThinLTO**，同时保留 `CFI_CLANG`、`SHADOW_CALL_STACK`、`MODVERSIONS`。
> 如果要在构建机上完全复刻原厂 `FULL LTO`，把 `CONFIG_LTO_CLANG_FULL=y` 打开并在内存 ≥ 8–12 GB 的 Linux 环境重建即可。

## 重要：不要提交到公开仓库

以下内容包含**设备唯一数据、个人数据或超大可再分发文件**，不要提交：

- `backup/`：`persist`、`nvram`、`nvdata`、`proinfo`、`efuse`、`lk`、`vbmeta`、`boot` 等分区镜像；
- `device_info.txt`：包含设备序列号；
- `kernel-build/out/`：编译产物、`vmlinux`、build log、`Module.symvers`、`new-boot.img` 等大文件；
- 小米官方源码 tar 包（约 200 MB；请从官方仓库下载）；
- 含个人应用列表、隐藏 Magisk 包名、账号、手机号、日志原文的报告。

发布前请先看 [`RELEASE-CHECKLIST.md`](RELEASE-CHECKLIST.md)。

## 许可 / Credits

- 本仓库的补丁基于 Linux kernel stable（GPL-2.0-only）；源码来自 Xiaomi Kernel Open Source（GPL-2.0）。
- 预编译引导镜像若通过 GitHub Releases 分发，请同时遵守 Magisk（GPL-3.0）等组件的许可，并附上对应源码/补丁与构建说明。
- `tools/ghostlock-extract` 来自 [YuKongA/ghostlock-app](https://github.com/YuKongA/ghostlock-app)，Apache-2.0。
- 本项目文档与脚本以 **GPL-2.0-only** 发布，详见 [`LICENSE`](LICENSE) 与 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。
