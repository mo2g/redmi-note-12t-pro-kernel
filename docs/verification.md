# 验证指南

## 刷入前

### 1. 检查新内核是否包含修复

```bash
tools/check_kernel.sh /path/to/new-boot.img
```

预期输出包含：

```text
rtmutex UAF fix is present
【结果】已修复 — remove_waiter 不再读取 current
```

### 2. vendor 模块 CRC 兼容性

在 Linux 环境安装 `kmod`，准备：

- 新内核构建产生的 `Module.symvers`
- 设备的 vendor 模块目录（可从手机导出）

```bash
python3 tools/module-crc-check.py \
  --symvers /path/to/out/Module.symvers \
  --modules /path/to/vendor-modules
```

预期：

```text
CRC mismatches: 0
```

> 目标设备验证结果：228 个模块、13,118 个符号引用，
> **11,397 匹配 / 0 不匹配**；未在 vmlinux 中的符号由其它 vendor 模块导出。

### 3. boot 镜像内容校验

- 新 boot 中的 `kernel` 应与编译出的 `Image` 一致；
- 新 boot 中的 `ramdisk.cpio` 应与原 Magisk 修补版一致；
- ramdisk 中应保留 `overlay.d`、`.backup` 等 Magisk 文件。

## 刷入后

```bash
# 1. 内核版本
adb shell uname -r
# 预期包含：5.10.136-pearl-cve43499

# 2. 修复检测（只读拉取 boot_a）
tools/check_kernel.sh
# 预期：已修复

# 3. root 保留
adb shell su -c id
# 预期：uid=0(root)

# 4. 模块加载错误
adb shell su -c 'dmesg | grep -iE "disagrees|version magic|Unknown symbol|module verification failed"'
# 预期：无输出

# 5. 关键模块
adb shell 'lsmod | grep -E "wlan_drv_gen4m|bt_drv|nvt36672c|xiaomi_touch|conninfra|gpu_plaid"'
```

### 功能自检清单

- [ ] Wi-Fi 打开并能连接
- [ ] 蓝牙打开并能扫描/连接
- [ ] 触摸正常
- [ ] 相机正常（前后摄）
- [ ] 指纹正常
- [ ] GPS 能定位
- [ ] 扬声器/听筒/麦克风正常
- [ ] 能拨打电话、能接听电话
- [ ] 重启后 Magisk root 仍在

## 如果再次崩溃

CVE-2026-43499 修复后，如果仍出现 `kernel_panic`，那属于另一个问题。请采集：

- `/sys/fs/pstore/console-ramoops-0`（root）
- `/data/vendor/aee_exp/db.fatal.*/ZZ_INTERNAL` 与 `db_history`
- `/data/system/dropbox/SYSTEM_LAST_KMSG*` 与 `SYSTEM_BOOT*`
- `adb shell getprop ro.boot.bootreason`、`persist.sys.boot.reason.history`

提交 issue 时请先删除序列号、IMEI、手机号、个人应用列表等敏感信息。

## Release 资产注意

GitHub Release 里的 `Image` / `Image.gz` 是**内核镜像**，不是完整的
`boot.img`，不能直接刷入 boot 分区。必须先用自己的 boot 备份 +
`scripts/pack-boot.sh` 打包成新的 boot 镜像，再执行 `check_kernel.sh` 验证后
才能刷入。原因和流程见 [`release-process.md`](release-process.md)。
