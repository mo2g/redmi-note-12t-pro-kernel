# 备份、刷入与回滚

> 本仓库不包含任何设备唯一分区镜像。请在你自己的设备上先做备份，并且
> **不要把备份提交到公开仓库**。

## 1. 刷入前：备份当前 boot 分区

先确认当前槽位：

```bash
adb shell getprop ro.boot.slot_suffix
# 例如 _a
```

只读导出当前 boot 分区（示例为 `boot_a`）：

```bash
adb exec-out su -c 'dd if=/dev/block/by-name/boot_a bs=1M 2>/dev/null' > boot_a.backup.img
shasum -a 256 boot_a.backup.img
```

把镜像和 SHA256 保存到电脑上，确认大小与分区一致（该设备为 64 MiB）。
刷入前建议再做一次校验，确保备份没有被截断。

## 2. 刷入

### 方式 A：fastboot（推荐，需要能稳定识别设备）

```bash
adb reboot bootloader
fastboot devices
fastboot flash boot_a /path/to/new-boot.img
fastboot reboot
```

如果 `fastboot flash` 卡住并出现 `could not clear pipe`，优先把 USB 直连
电脑（不要经过 Hub/扩展坞），或在 bootloader 里重新插拔后再试。

### 方式 B：root dd（fastboot 不稳定时的替代）

```bash
adb push /path/to/new-boot.img /data/local/tmp/new-boot.img
adb shell su -c 'sha256sum /data/local/tmp/new-boot.img'
# 与电脑端 SHA256 对比

adb shell su -c 'dd if=/data/local/tmp/new-boot.img of=/dev/block/by-name/boot_a bs=1M; sync'
adb exec-out su -c 'dd if=/dev/block/by-name/boot_a bs=1M 2>/dev/null' > boot_a.after.img
shasum -a 256 boot_a.after.img
# 应与 new-boot.img 完全一致

adb shell su -c 'rm -f /data/local/tmp/new-boot.img; sync'
adb reboot
```

`dd` 方式是直接写块设备；写入过程中不要断电、不要拔线。电量建议在 50%
以上（最好接 USB 供电，但不要依赖不稳定的 Hub）。

## 3. 回滚

### fastboot 回滚

```bash
fastboot flash boot_a /path/to/boot_a.backup.img
fastboot reboot
```

### root dd 回滚

```bash
adb push /path/to/boot_a.backup.img /data/local/tmp/boot_a.backup.img
adb shell su -c 'sha256sum /data/local/tmp/boot_a.backup.img'
adb shell su -c 'dd if=/data/local/tmp/boot_a.backup.img of=/dev/block/by-name/boot_a bs=1M; sync'
adb shell su -c 'rm -f /data/local/tmp/boot_a.backup.img; sync'
adb reboot
```

回滚只影响 boot 分区，不会清除用户数据；但如果错误地写到其它分区，可能
造成不可恢复的后果。**不要碰 `persist`、`nvram`、`nvdata`、`proinfo`、
`efuse`、`lk` 等分区。**

## 4. 如果刷后无法开机

1. 断开 USB，长按电源键 10–15 秒强制重启；
2. 若仍黑屏，按住 **音量减 + 电源** 进入 fastboot；
3. 用上面的 fastboot 回滚命令刷回备份；
4. 如果 fastboot 也不可用，使用官方线刷包恢复（会清除数据，优先考虑售后/官方工具）。
