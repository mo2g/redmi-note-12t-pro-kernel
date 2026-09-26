#!/usr/bin/env bash
# Build a CVE-2026-43499-fixed kernel for Redmi Note 12T Pro (pearl).
#
# Usage:
#   scripts/build-kernel.sh /path/to/pearl-kernel [config]
#
# Environment:
#   OUT=...        build directory (default: <source>/out)
#   JOBS=...       parallel make jobs (default: nproc)
#   THIN_LTO=1     use ThinLTO (default; lower memory). Set 0 for stock FULL LTO.
#   LOCALVERSION=...  default: -pearl-cve43499
set -euo pipefail

SRC=${1:?usage: $0 <pearl-kernel-source-dir> [device_kconfig.txt]}
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
KCONFIG=${2:-"$REPO_DIR/configs/device_kconfig.txt"}
OUT=${OUT:-"$SRC/out"}
JOBS=${JOBS:-$(nproc 2>/dev/null || echo 4)}
TARGET=${TARGET:-Image.gz}
THIN_LTO=${THIN_LTO:-1}
LOCALVERSION=${LOCALVERSION:--pearl-cve43499}

[ "$(uname -s)" = "Linux" ] || { echo "error: kernel build requires Linux"; exit 2; }
[ -f "$SRC/Makefile" ] || { echo "error: not a kernel source tree: $SRC"; exit 2; }
[ -f "$KCONFIG" ] || { echo "error: kconfig not found: $KCONFIG"; exit 2; }
command -v clang >/dev/null || { echo "error: clang not found in PATH"; exit 2; }
command -v ld.lld >/dev/null || { echo "error: ld.lld not found in PATH"; exit 2; }

# On x86_64/other hosts, clang defaults to the host architecture. Tell the
# kernel build to target aarch64; on an arm64 host this is not needed.
HOST_ARCH=$(uname -m)
case "$HOST_ARCH" in
  aarch64|arm64) ;;
  *)
    export CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
    export CLANG_TRIPLE=${CLANG_TRIPLE:-aarch64-linux-gnu-}
    echo "info: cross-compiling for arm64 (CROSS_COMPILE=$CROSS_COMPILE)"
    ;;
esac

grep -q '^SUBLEVEL = 136' "$SRC/Makefile" || {
  echo "warning: source is not 5.10.136; patch context may differ"
}

# The Xiaomi source tarball ships x86_64 cpio/tar prebuilts. Replace them on
# arm64 hosts so kheaders generation works.
for tool in cpio tar; do
  if [ -f "$SRC/tools/build/$tool" ] && file "$SRC/tools/build/$tool" | grep -q 'x86-64'; then
    echo "info: replacing x86_64 tools/build/$tool with host $tool"
    mv "$SRC/tools/build/$tool" "$SRC/tools/build/$tool.x86_64.bak"
    ln -s "$(command -v "$tool")" "$SRC/tools/build/$tool"
  fi
done

# Apply patches once.
if ! grep -q 'waiter_task = waiter->task' "$SRC/kernel/locking/rtmutex.c"; then
  echo "info: applying CVE-2026-43499 patches"
  patch -d "$SRC" -p1 < "$REPO_DIR/patches/0001-rtmutex-use-waiter-task-in-remove_waiter.patch"
  patch -d "$SRC" -p1 < "$REPO_DIR/patches/0002-rtmutex-skip-remove_waiter-when-not-enqueued.patch"
else
  echo "info: patches already applied"
fi

mkdir -p "$OUT"
cp "$KCONFIG" "$OUT/.config"

"$SRC/scripts/config" --file "$OUT/.config" \
  --disable DEBUG_INFO \
  --disable DEBUG_INFO_DWARF4 \
  --disable TRIM_UNUSED_KSYMS \
  --disable LOCALVERSION_AUTO \
  --set-str LOCALVERSION "$LOCALVERSION"

if [ "$THIN_LTO" = "1" ]; then
  echo "info: using ThinLTO (set THIN_LTO=0 for stock FULL LTO)"
  "$SRC/scripts/config" --file "$OUT/.config" \
    --disable LTO_CLANG_FULL --enable LTO_CLANG_THIN
fi

make -C "$SRC" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
if [ -n "$TARGET" ]; then
  make -C "$SRC" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 -j"$JOBS" "$TARGET"
else
  make -C "$SRC" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 -j"$JOBS"
fi

# Building only Image.gz does not run the module post-processing step, so
# Module.symvers is not created. vmlinux.symvers contains the kernel-exported
# symbol CRCs and is sufficient for the vendor module compatibility check.
if [ ! -f "$OUT/Module.symvers" ] && [ -f "$OUT/vmlinux.symvers" ]; then
  cp "$OUT/vmlinux.symvers" "$OUT/Module.symvers"
  echo "info: created $OUT/Module.symvers from vmlinux.symvers (image-only build)"
fi

echo
echo "built: $OUT/arch/arm64/boot/Image (and Image.gz when TARGET=Image.gz)"
echo "verify: $REPO_DIR/tools/check_kernel.sh $OUT/arch/arm64/boot/Image"
