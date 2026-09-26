# Tools

## check_kernel.sh

只读检测设备当前 boot 分区（或指定 boot 镜像）是否包含 CVE-2026-43499 修复。

```bash
./check_kernel.sh
./check_kernel.sh /path/to/boot.img
```

- 不带参数：通过 `adb + su` 从当前槽位拉取 boot 镜像（不在手机落文件）
- 退出码：`0` 已修复，`1` 未修复，`2` 检测失败
- 依赖同目录的 `ghostlock-extract`

## ghostlock-extract

来自 [YuKongA/ghostlock-app](https://github.com/YuKongA/ghostlock-app)
（Apache-2.0）的内核检查器。本仓库内附的是 **macOS arm64** 便利二进制。

- 支持：boot.img、raw arm64 Image、gzip Image、payload.bin、OTA ZIP/URL
- Linux / 其他平台请按上游 README 用 Rust 构建，或直接使用上游 release
- 该工具只做提取/检测，不写分区

## module-crc-check.py

批量比对 vendor `.ko` 模块引用的符号 CRC 与内核 `Module.symvers`：

```bash
python3 module-crc-check.py \
  --symvers /path/to/out/Module.symvers \
  --modules /path/to/vendor-modules
```

- 需要 Linux 上的 `kmod`（提供 `modprobe`）
- 只报告 **CRC mismatch**；缺失符号可能由其它 vendor 模块导出，会单独列出
- 退出码：`0` 无 mismatch，`1` 有 mismatch，`2` 使用/环境错误

> 目标设备验证：228 个模块、13,118 个符号引用，11,397 匹配 / 0 不匹配。
