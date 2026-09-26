#!/usr/bin/env bash
# Replace the kernel in an existing Magisk-patched boot image while preserving
# its ramdisk (and therefore Magisk).
#
# Usage:
#   MAGISKBOOT=/path/to/magiskboot scripts/pack-boot.sh \
#     original-boot_a.img out/arch/arm64/boot/Image new-boot.img
set -euo pipefail

ORIG=${1:?usage: $0 <original-boot.img> <Image> [new-boot.img]}
KERNEL=${2:?usage: $0 <original-boot.img> <Image> [new-boot.img]}
OUT=${3:-new-boot.img}
MAGISKBOOT=${MAGISKBOOT:-magiskboot}

[ -f "$ORIG" ] || { echo "error: original boot not found: $ORIG"; exit 2; }
[ -f "$KERNEL" ] || { echo "error: kernel Image not found: $KERNEL"; exit 2; }
command -v "$MAGISKBOOT" >/dev/null 2>&1 || [ -x "$MAGISKBOOT" ] || {
  echo "error: magiskboot not found (set MAGISKBOOT)"; exit 2;
}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

cp "$ORIG" orig.img
"$MAGISKBOOT" unpack orig.img
mkdir -p repack verify
cp "$KERNEL" repack/kernel
cp ramdisk.cpio repack/ramdisk.cpio

(
  cd repack
  "$MAGISKBOOT" repack "$WORK/orig.img" "$WORK/new-boot.img"
)
cp new-boot.img "$OUT"

(
  cd verify
  "$MAGISKBOOT" unpack "$WORK/new-boot.img"
  k_ok=0; r_ok=0
  [ "$(sha256 kernel)" = "$(sha256 "$KERNEL")" ] && k_ok=1
  [ "$(sha256 ramdisk.cpio)" = "$(sha256 "$WORK/ramdisk.cpio")" ] && r_ok=1
  echo "kernel_match=$k_ok ramdisk_match=$r_ok"
  [ "$k_ok" = "1" ] && [ "$r_ok" = "1" ]
)

echo "packed: $OUT"
echo "verify: tools/check_kernel.sh $OUT"
