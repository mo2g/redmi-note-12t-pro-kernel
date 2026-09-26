#!/usr/bin/env bash
# Prepare GitHub Release assets for redmi-note-12t-pro-kernel.
#
# Usage:
#   scripts/prepare-release-assets.sh \
#     --tag v1.0.0-cve-2026-43499 \
#     --image out/arch/arm64/boot/Image \
#     --image-gz out/arch/arm64/boot/Image.gz \
#     --symvers out/Module.symvers \
#     --kconfig configs/device_kconfig.txt \
#     --out dist
set -euo pipefail

TAG=""
IMAGE=""
IMAGE_GZ=""
SYMVERS=""
KCONFIG="configs/device_kconfig.txt"
OUT="dist"

while [ $# -gt 0 ]; do
  case "$1" in
    --tag) TAG=${2:?}; shift 2 ;;
    --image) IMAGE=${2:?}; shift 2 ;;
    --image-gz) IMAGE_GZ=${2:?}; shift 2 ;;
    --symvers) SYMVERS=${2:?}; shift 2 ;;
    --kconfig) KCONFIG=${2:?}; shift 2 ;;
    --out) OUT=${2:?}; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$TAG" ] || { echo "error: --tag is required" >&2; exit 2; }
[ -f "$IMAGE_GZ" ] || { echo "error: --image-gz not found: $IMAGE_GZ" >&2; exit 2; }
[ -f "$SYMVERS" ] || { echo "error: --symvers not found: $SYMVERS" >&2; exit 2; }
[ -f "$KCONFIG" ] || { echo "error: --kconfig not found: $KCONFIG" >&2; exit 2; }

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

BASE="redmi-note-12t-pro-kernel-${TAG}"
rm -rf "$OUT"
mkdir -p "$OUT"

cp "$IMAGE_GZ" "$OUT/${BASE}-Image.gz"
cp "$SYMVERS" "$OUT/${BASE}-Module.symvers"
cp "$KCONFIG" "$OUT/${BASE}-device_kconfig.patched"
if [ -n "$IMAGE" ] && [ -f "$IMAGE" ]; then
  cp "$IMAGE" "$OUT/${BASE}-Image"
  KERNEL_VERSION=$(strings -a "$IMAGE" | grep -m1 -E '^Linux version 5\.10\.136' || true)
else
  KERNEL_VERSION=$(gzip -dc "$IMAGE_GZ" 2>/dev/null | strings -a | grep -m1 -E '^Linux version 5\.10\.136' || true)
fi

BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TOOLCHAIN=$( (clang --version 2>/dev/null || echo "clang (version unknown)") | head -n1)

cat > "$OUT/build-info.txt" <<BUILD_INFO_EOF
release: ${TAG}
device: Redmi Note 12T Pro (pearl, MT6895/MT6896)
source: MiCode/Xiaomi_Kernel_OpenSource @ d96c1a04b701bcf1d39ed1b8ab4b3137ff6490f9 (5.10.136)
patches: 0001 f3fa3424 + 0002 bfbc047c (CVE-2026-43499, Linux 5.10.260 backport)
kernel_version: ${KERNEL_VERSION:-unknown}
toolchain: ${TOOLCHAIN}
build_date: ${BUILD_DATE}
config: ThinLTO + CFI_CLANG + SHADOW_CALL_STACK + MODVERSIONS (see ${BASE}-device_kconfig.patched)
BUILD_INFO_EOF

cat > "$OUT/release-notes.md" <<RELEASE_NOTES_EOF
# ${TAG}

CVE-2026-43499 fix for the **Redmi Note 12T Pro** (codename \`pearl\`, MT6895/MT6896) on MIUI 14 / 5.10.136.

## What is in this release

- \`${BASE}-Image.gz\` — compressed ARM64 kernel Image
- \`${BASE}-Image\` — raw ARM64 kernel Image (optional)
- \`${BASE}-Module.symvers\` — exported symbol CRC table
- \`${BASE}-device_kconfig.patched\` — kernel config used for this build
- \`build-info.txt\` — source, patch, toolchain and build metadata
- \`SHA256SUMS\` — checksums

## Important: these are kernel-only assets

This release does **not** contain a ready-to-flash \`boot.img\`. A boot image also
contains a ROM- and Magisk-specific ramdisk; publishing one image for everyone is
unsafe and unnecessary.

To use these assets:

1. Back up your current boot partition (see \`docs/rollback.md\`).
2. Download and decompress the kernel: \`gzip -d ${BASE}-Image.gz\`.
3. Repack it into **your own** Magisk-patched boot backup:
   \`\`\`
   MAGISKBOOT=/path/to/magiskboot scripts/pack-boot.sh \\
     /path/to/your-boot_a.backup.img ${BASE}-Image new-boot.img
   \`\`\`
4. Verify the new boot image: \`tools/check_kernel.sh new-boot.img\`.
5. Flash it with fastboot or root \`dd\` (see \`docs/rollback.md\`).

Requirements: bootloader unlocked, matching \`pearl\` / MIUI \`V14.0.5.0.TLHCNXM\`
(or a compatible vendor module set), and a backup of your original boot partition.

## Verification

- Built from the official Xiaomi \`pearl-s-oss\` source tree with the official
  Linux 5.10.260 CVE-2026-43499 backports.
- The release workflow runs the upstream GhostLock detector on the built Image
  and fails if \`remove_waiter()\` still reads \`current\`.

## License

Kernel patches and source are GPL-2.0. See \`THIRD_PARTY_NOTICES.md\` in the
repository. Magisk is GPL-3.0.
RELEASE_NOTES_EOF

(
  cd "$OUT"
  : > SHA256SUMS
  for f in *; do
    [ "$f" = "SHA256SUMS" ] && continue
    printf '%s  %s\n' "$(sha256 "$f")" "$f" >> SHA256SUMS
  done
)

echo "prepared assets in $OUT:"
ls -lh "$OUT"
echo
echo "publish with:"
echo "  gh release create ${TAG} ${OUT}/* --title \"redmi-note-12t-pro-kernel ${TAG}\" --notes-file ${OUT}/release-notes.md"
