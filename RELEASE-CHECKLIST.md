# 发布检查清单

## 提交前：敏感信息扫描

```bash
# 1. 不应出现的字符串（按需补充你自己的设备信息）
grep -RInE '你的序列号|你的IMEI|手机号|atgcy\.|真实隐藏包名' .

# 2. 不应出现的目录/文件
find . -maxdepth 2 \( -name '*.img' -o -name '*.tar.gz' -o -name '*.log' \
  -o -name '*.ko' -o -name 'Module.symvers' -o -name 'device_info.txt' \) -print

# 3. 大文件检查
du -ah . | sort -h | tail -n 20
```

## 绝对不要提交

- `backup/` 目录及其任何 `.img`（`persist`、`nvram`、`nvdata`、`proinfo`、
  `efuse`、`lk`、`vbmeta`、`boot` 等）
- `device_info.txt`（含设备序列号）
- `kernel-build/out/`（`vmlinux`、`Image`、`new-boot.img`、build log、
  `Module.symvers` 等）
- 小米官方源码 tar 包（约 200 MB）
- 个人日志原文、个人应用/模块列表、隐藏 Magisk 包名、账号/手机号/IMEI

`.gitignore` 已默认忽略这些内容，但仍建议发布前人工确认 `git status`。

## 自动 Release（推荐）

仓库包含 `.github/workflows/release.yml`，推送 `v*` 标签会自动构建并发布：

```bash
git tag v1.0.0-cve-2026-43499
git push origin v1.0.0-cve-2026-43499
```

自动 Release 的资产是 **kernel-only**：

- `...-Image.gz`
- `...-Image`
- `...-Module.symvers`
- `...-device_kconfig.patched`
- `build-info.txt`
- `SHA256SUMS`

**不自动发布 `boot.img`**。boot 镜像包含与 ROM/Magisk 相关的 ramdisk，用户应
使用自己的 boot 备份 + `scripts/pack-boot.sh` 打包，详见 `docs/release-process.md`。

本地手动准备资产（CI 不可用时）：

```bash
scripts/prepare-release-assets.sh   --tag v1.0.0-cve-2026-43499   --image out/arch/arm64/boot/Image   --image-gz out/arch/arm64/boot/Image.gz   --symvers out/Module.symvers   --kconfig configs/device_kconfig.txt   --out dist

gh release create v1.0.0-cve-2026-43499 dist/* \
  --title "redmi-note-12t-pro-kernel v1.0.0-cve-2026-43499" \
  --notes-file dist/release-notes.md
```

## 手动发布 boot 镜像（高级，不推荐）

只有在明确知道 ROM/Magisk 版本、且愿意承担误刷风险时才这样做：

- 只针对一个精确 ROM 版本（例如 `V14.0.5.0.TLHCNXM`）发布；
- 明确标注是否包含 Magisk ramdisk；
- 附 SHA256、适用机型、回滚方法；
- 遵守 Magisk GPL-3.0 与内核 GPL-2.0 的许可要求；
- 提醒用户：其他 ROM/版本不要刷，误刷需自行回滚。

## GitHub About 建议

- 名称：`redmi-note-12t-pro-kernel`
- Description（English，默认）：
  `Unofficial kernel patches, security fixes, and tools for the Redmi Note 12T Pro (pearl); currently includes the CVE-2026-43499 fix.`
- 中文描述（备用）：
  `Redmi Note 12T Pro (pearl) 非官方内核补丁/安全修复与工具集；当前包含 CVE-2026-43499。`
- Topics：
  `redmi-note-12t-pro`, `pearl`, `mt6895`, `mediatek`, `miui`,
  `android-kernel`, `kernel-patches`, `kernel-security`, `cve-2026-43499`,
  `rtmutex`, `futex`

## 推送到已创建的 GitHub 仓库

```bash
cd redmi-note-12t-pro-kernel
git remote add origin https://github.com/mo2g/redmi-note-12t-pro-kernel.git
git push -u origin main
```

如果没有配置 HTTPS 凭据，可以使用 SSH：

```bash
git remote set-url origin git@github.com:mo2g/redmi-note-12t-pro-kernel.git
git push -u origin main
```
