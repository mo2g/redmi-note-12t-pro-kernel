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

## 如果要发布预编译 boot 镜像

建议使用 **GitHub Releases**，不要提交进 git：

- 资产：`new-boot.img`（或 `Image.gz`）
- 必备说明：
  - 适用机型/ROM/内核版本：`pearl` / `V14.0.5.0.TLHCNXM` / 5.10.136
  - 内核版本串：`5.10.136-pearl-cve43499`
  - 源码提交 `d96c1a04...` + 本仓库两个补丁
  - 构建工具链、构建日期、是否 ThinLTO/FULL LTO
  - SHA256
  - 已知限制与风险：仅适用于匹配的 ROM/分区布局；刷机有风险；需解锁 BL；
    需自行备份 boot 分区
- 合规：如包含 Magisk ramdisk，请遵守 Magisk GPL-3.0 并附源码链接；
  内核补丁/源码为 GPL-2.0。

## GitHub About 建议

- 名称：`redmi-note-12t-pro-kernel`
- 描述（中文）：
  `Redmi Note 12T Pro (pearl) 非官方内核补丁/安全修复与工具集；当前包含 CVE-2026-43499。`
- Description (English):
  `Unofficial kernel patches, security fixes, and tools for Redmi Note 12T Pro (pearl); currently includes CVE-2026-43499.`
- Topics：
  `redmi-note-12t-pro`, `pearl`, `mt6895`, `mediatek`, `miui`,
  `android-kernel`, `kernel-patches`, `kernel-security`, `cve-2026-43499`,
  `rtmutex`, `futex`

## 推荐初始化命令

```bash
cd redmi-note-12t-pro-kernel
git init -b main
git add .
git commit -m "Initial release: CVE-2026-43499 fix for Redmi Note 12T Pro (pearl)"
# 创建 GitHub 仓库（需已安装并登录 gh）
gh repo create redmi-note-12t-pro-kernel --public --source=. --remote=origin --push
```
