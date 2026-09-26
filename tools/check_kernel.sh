#!/bin/bash
# check_kernel.sh — 检测内核是否含 CVE-2026-43499 的修复（只读检测）
#
# 用法:
#   ./check_kernel.sh                       # 从手机实时拉取当前槽 boot 并检测
#   ./check_kernel.sh /path/to/boot.img     # 检测指定的 boot 镜像
#
# 退出码: 0=已修复  1=未修复  2=检测失败
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/ghostlock-extract"
IMG="${1:-}"

[ -x "$BIN" ] || { echo "[!] 缺少可执行文件: $BIN"; exit 2; }

if [ -z "$IMG" ]; then
  SLOT=$(adb shell getprop ro.boot.slot_suffix 2>/dev/null | tr -d '\r')
  [ -n "$SLOT" ] || SLOT=_a
  PART="boot${SLOT}"
  IMG="/tmp/gl_check_${PART}.img"
  echo "[*] 从设备拉取 /dev/block/by-name/$PART (只读, 不在手机落文件) ..."
  adb exec-out "su -c 'dd if=/dev/block/by-name/$PART bs=1M 2>/dev/null'" > "$IMG" || { echo "[!] 拉取失败"; exit 2; }
  SZ=$(stat -f%z "$IMG" 2>/dev/null || stat -c%s "$IMG")
  [ "$SZ" -gt 1000000 ] || { echo "[!] 镜像异常($SZ bytes)"; exit 2; }
  echo "    已保存: $IMG ($SZ bytes)"
fi

[ -f "$IMG" ] || { echo "[!] 镜像不存在: $IMG"; exit 2; }

echo "[*] 分析 $IMG ..."
OUT=$("$BIN" "$IMG" 2>&1); RC=$?
echo "$OUT" | grep -E 'primitive present|rtmutex UAF fix|cannot check|kallsyms' | sed 's/^/    /'
echo
if echo "$OUT" | grep -q 'primitive present'; then
  echo "  【结果】未修复 — 漏洞原语存在（remove_waiter 仍读取 current）"
  exit 1
elif [ "$RC" = "6" ] || echo "$OUT" | grep -q 'rtmutex UAF fix'; then
  echo "  【结果】已修复 — remove_waiter 不再读取 current"
  exit 0
else
  echo "  【结果】无法判定（提取器 exit=$RC）"
  exit 2
fi
