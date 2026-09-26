# 自动 Release 流程

## 目标

让用户可以直接从 GitHub Releases 下载**经过验证的内核产物**，同时避免分发
与 ROM/Magisk 强绑定的 boot 镜像。

自动 Release 发布的是 **kernel-only** 资产：

- `Image.gz`
- `Image`（raw）
- `Module.symvers`
- `device_kconfig.patched`
- `build-info.txt`
- `SHA256SUMS`

不自动发布 `boot.img`。原因：

- boot 镜像还包含 ROM 版本、Magisk 版本相关的 ramdisk；
- 同一台 `pearl` 在不同 MIUI 版本/不同 Magisk 配置下，ramdisk 可能不同；
- 自动生成一个“通用 boot.img”容易导致用户误刷、无法开机；
- 用户应使用自己的 boot 备份 + `scripts/pack-boot.sh` 打包，这既能保留自己的
  Magisk/ramdisk，也能避免分发不必要的厂商镜像。

## 触发方式

```bash
git tag v1.0.0-cve-2026-43499
git push origin v1.0.0-cve-2026-43499
```

推送 `v*` 标签后，[`.github/workflows/release.yml`](../.github/workflows/release.yml)
会自动执行：

1. checkout 本仓库；
2. 安装 clang 12 / LLD 12 与构建依赖；
3. 下载固定提交的官方源码
   `MiCode/Xiaomi_Kernel_OpenSource @ d96c1a04...`；
4. 应用 `patches/` 中的两个 5.10.260 backport；
5. 使用 `configs/device_kconfig.txt`，以 ThinLTO + CFI + SCS + MODVERSIONS 构建
   `Image.gz`；
6. 从上游 `YuKongA/ghostlock-app` 构建 Linux 版检测器，并验证
   `remove_waiter()` 不再读取 `current`；
7. 用 `scripts/prepare-release-assets.sh` 生成资产与 `SHA256SUMS`；
8. 通过 `gh release create` 发布 GitHub Release。

## 用户如何使用 Release 资产

1. 先备份自己的 boot 分区（见 [`rollback.md`](rollback.md)）；
2. 下载 `...-Image.gz` 并解压：`gzip -d ...-Image.gz`；
3. 用 `scripts/pack-boot.sh` 将新内核替换进**自己的** Magisk 修补 boot 备份：

   ```bash
   MAGISKBOOT=/path/to/magiskboot \
     scripts/pack-boot.sh \
     /path/to/your-boot_a.backup.img \
     redmi-note-12t-pro-kernel-vX.Y.Z-cve-...-Image \
     new-boot.img
   ```

4. 用 `tools/check_kernel.sh new-boot.img` 验证；
5. 再按 [`rollback.md`](rollback.md) 用 fastboot 或 root `dd` 刷入。

## 手动发布（备用）

如果 CI 暂时不可用，可以在本地构建后手动准备资产：

```bash
scripts/prepare-release-assets.sh \
  --tag v1.0.0-cve-2026-43499 \
  --image out/arch/arm64/boot/Image \
  --image-gz out/arch/arm64/boot/Image.gz \
  --symvers out/Module.symvers \
  --kconfig configs/device_kconfig.txt \
  --out dist

# 需已安装并登录 gh
gh release create v1.0.0-cve-2026-43499 dist/* \
  --title "redmi-note-12t-pro-kernel v1.0.0-cve-2026-43499" \
  --notes-file dist/release-notes.md
```

## CI 注意事项

- **构建时间**：GitHub Actions 标准 Linux runner 上，ThinLTO 构建通常需要
  20–60 分钟；FULL LTO 在低内存 runner 上可能 OOM，因此默认使用 ThinLTO。
- **磁盘空间**：workflow 会先清理 runner 上的 Android SDK/.NET/CodeQL 等目录；
  内核源码 + 构建产物约 5–10 GB。
- **工具链**：使用 Ubuntu 22.04 的 clang-12 / lld-12 / llvm-12。与官方
  r416183b（clang 12.0.5）有微小版本差异，但已验证 `module_layout` 等 CRC 一致。
- **检测器**：上游 GhostLock 检测器需要 Rust；workflow 会安装 stable Rust，
  并使用 `--ignore-rust-version` 构建。检测器返回 6 或输出
  `rtmutex UAF fix is present` 才视为通过。
- **失败处理**：任何一步失败都不会创建 Release；workflow artifact 可用于排查。

## 是否要发布 boot.img？

默认不发布。若维护者确实要发布手工构建的 boot 镜像，必须：

- 只针对一个精确 ROM 版本（例如 `V14.0.5.0.TLHCNXM`）；
- 明确标注“包含 Magisk ramdisk / 不包含 Magisk ramdisk”；
- 附 SHA256、适用机型、回滚方法；
- 遵守 Magisk GPL-3.0 与内核 GPL-2.0 的许可要求；
- 明确提示：其他 ROM/版本用户不要刷，误刷需自行回滚。

更推荐的做法是只发布 kernel-only 资产，让用户用自己的 boot 备份打包。
