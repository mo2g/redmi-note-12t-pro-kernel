# 编译与打包指南

本指南记录的是在目标设备上实际验证过的流程：从官方源码编译 `Image`，再
用 `magiskboot` 替换原 boot 镜像的内核、保留 Magisk ramdisk。

> 刷入有风险；请先阅读 `docs/rollback.md` 并备份原 boot 分区。

## 1. 环境要求

- Linux（推荐 Ubuntu 22.04 arm64 或 x86_64；也可靠 Docker）
- clang / LLD 12（原厂使用 AOSP clang r416183b，即 clang 12.0.5；
  Ubuntu 22.04 的 clang 12.0.1 也验证可用）
- `make bc bison flex libssl-dev libelf-dev python3 cpio tar kmod`
- 磁盘：源码 + 构建产物建议预留 20 GB 以上
- 内存：FULL LTO + CFI 构建建议 ≥ 8–12 GB；内存不足时改用 ThinLTO

Docker 示例（Ubuntu 22.04 arm64）：

```bash
docker run -it --name pearl-build ubuntu:22.04 bash
apt-get update
apt-get install -y build-essential make bc bison flex libssl-dev libelf-dev \
  python3 python3-distutils zip unzip xz-utils git curl ca-certificates \
  clang-12 lld-12 llvm-12 gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
  kmod cpio rsync patch file
mkdir -p /usr/local/llvm12/bin
for t in clang clang++ ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump \
         llvm-readelf llvm-size llvm-strip llvm-ranlib; do
  src=$(command -v ${t}-12 || true)
  [ -n "$src" ] && ln -sf "$src" /usr/local/llvm12/bin/$t
done
export PATH=/usr/local/llvm12/bin:$PATH
```

如果系统只有 `python3` 而没有 `python`：

```bash
apt-get install -y python-is-python3
# 或： ln -s "$(command -v python3)" /usr/local/bin/python
```

## 2. 获取官方源码

```bash
curl -L -o pearl-s-oss.tar.gz \
  https://codeload.github.com/MiCode/Xiaomi_Kernel_OpenSource/tar.gz/d96c1a04b701bcf1d39ed1b8ab4b3137ff6490f9
mkdir -p src && tar -xzf pearl-s-oss.tar.gz -C src
mv src/Xiaomi_Kernel_OpenSource-* pearl-kernel
cd pearl-kernel
grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL)' Makefile
# 预期：5.10.136
```

## 3. 应用补丁

在源码根目录执行（顺序不能反）：

```bash
patch -p1 < /path/to/pearl-kernel-cve-2026-43499/patches/0001-rtmutex-use-waiter-task-in-remove_waiter.patch
patch -p1 < /path/to/pearl-kernel-cve-2026-43499/patches/0002-rtmutex-skip-remove_waiter-when-not-enqueued.patch
```

验证：

```bash
awk '/static void remove_waiter/,/^}/' kernel/locking/rtmutex.c | grep -n current
# 预期：无输出
grep -n 'waiter_task' kernel/locking/rtmutex.c | head
# 预期：能看到 waiter_task = waiter->task 以及后续使用
```

## 4. 配置

```bash
mkdir -p out
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 pearl_defconfig
cp /path/to/pearl-kernel-cve-2026-43499/configs/device_kconfig.txt out/.config

# 便于识别 + 减少构建体积/内存
scripts/config --file out/.config \
  --disable DEBUG_INFO \
  --disable DEBUG_INFO_DWARF4 \
  --disable TRIM_UNUSED_KSYMS \
  --disable LOCALVERSION_AUTO \
  --set-str LOCALVERSION "-pearl-cve43499"

# 内存不足时（< 8 GB）可选：FULL LTO -> ThinLTO
scripts/config --file out/.config \
  --disable LTO_CLANG_FULL \
  --enable  LTO_CLANG_THIN

make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
```

保留的安全加固：`CFI_CLANG`、`CFI_CLANG_SHADOW`、`SHADOW_CALL_STACK`、
`MODVERSIONS`。关闭 `TRIM_UNUSED_KSYMS` 是为了避免裁剪 vendor 模块需要的
导出符号。

## 5. 编译

```bash
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 -j"$(nproc)"
ls -lh out/arch/arm64/boot/Image out/arch/arm64/boot/Image.gz
```

### 常见问题

1. **`tools/build/cpio: cannot execute binary file` / x86_64 loader 错误**
   小米源码包含 x86_64 预编译的 `tools/build/cpio` 和 `tools/build/tar`。
   在 arm64 构建机上换成系统原生工具：
   ```bash
   mv tools/build/cpio tools/build/cpio.x86_64.bak
   mv tools/build/tar  tools/build/tar.x86_64.bak
   ln -s "$(command -v cpio)" tools/build/cpio
   ln -s "$(command -v tar)"  tools/build/tar
   ```
2. **`python: not found`**
   安装 `python-is-python3` 或创建 `python -> python3` 符号链接。
3. **FULL LTO 链接被 OOM killed**
   使用 ThinLTO（见上），或在内存 ≥ 8–12 GB 的环境中构建 FULL LTO。
   两者都保留 CFI；本仓库的验证构建使用 ThinLTO。

## 6. 打包为 boot.img（保留 Magisk）

思路：**只替换 kernel，ramdisk 保持原样**。

```bash
# 以原 Magisk 修补版 boot_a 为例
mkdir -p pack && cd pack
cp /path/to/original-boot_a.img .
magiskboot unpack original-boot_a.img
cp /path/to/pearl-kernel/out/arch/arm64/boot/Image kernel
mkdir -p repack && cp kernel repack/kernel && cp ramdisk.cpio repack/ramdisk.cpio
cd repack
magiskboot repack ../original-boot_a.img ../new-boot.img
```

`magiskboot` 会按原 boot 镜像记录的格式重新压缩（该设备为
`KERNEL_FMT=gzip`、`RAMDISK_FMT=lz4_legacy`）。

验证新 boot：

```bash
# 内核区段应与 out/arch/arm64/boot/Image 一致；ramdisk 应与原解包结果一致
mkdir -p verify && cd verify
magiskboot unpack ../new-boot.img
sha256sum kernel ramdisk.cpio
# 并检查 ramdisk 中保留 Magisk 文件：
magiskboot cpio ramdisk.cpio ls | grep -E 'overlay.d|\.backup'
```

## 7. 刷入前验证

- `tools/check_kernel.sh new-boot.img` → 必须显示「已修复」
- `tools/module-crc-check.py` → 不应有 CRC mismatch
- 确认 `boot_a` / `boot_b` 中要刷的分区与原备份一致，并已保存备份

刷入与回滚见 `docs/rollback.md`。刷入后按 `docs/verification.md` 做功能自检。
