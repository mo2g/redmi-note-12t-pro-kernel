#!/usr/bin/env python3
"""Compare vendor module symbol CRCs against a kernel Module.symvers.

Usage:
  python3 module-crc-check.py --symvers out/Module.symvers --modules vendor-modules

Requires Linux `kmod` (provides `modprobe --dump-modversions`).
Only CRC mismatches are fatal; symbols missing from vmlinux may be exported by
other vendor modules and are reported separately.
"""
from __future__ import annotations

import argparse
import collections
import pathlib
import subprocess
import sys


def parse_symvers(path: pathlib.Path) -> dict[str, str]:
    symvers: dict[str, str] = {}
    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 2 and parts[0].startswith("0x"):
                symvers[parts[1]] = parts[0].lower()
    return symvers


def iter_modules(path: pathlib.Path):
    if path.is_file() and path.suffix == ".ko":
        yield path
        return
    yield from sorted(path.rglob("*.ko"))


def dump_versions(modprobe: str, module: pathlib.Path) -> dict[str, str]:
    out = subprocess.check_output(
        [modprobe, "--dump-modversions", str(module)],
        stderr=subprocess.DEVNULL,
        text=True,
    )
    versions: dict[str, str] = {}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0].startswith("0x"):
            versions[parts[1]] = parts[0].lower()
    return versions


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--symvers", required=True, type=pathlib.Path,
                    help="path to kernel Module.symvers")
    ap.add_argument("--modules", required=True, type=pathlib.Path,
                    help="vendor module .ko file or directory")
    ap.add_argument("--modprobe", default="modprobe",
                    help="modprobe binary (default: modprobe)")
    ap.add_argument("--show-missing", type=int, default=20,
                    help="how many missing symbols to print (default: 20)")
    args = ap.parse_args()

    if not args.symvers.is_file():
        print(f"error: symvers not found: {args.symvers}", file=sys.stderr)
        return 2
    if not args.modules.exists():
        print(f"error: modules path not found: {args.modules}", file=sys.stderr)
        return 2
    if not subprocess.run([args.modprobe, "--version"],
                          stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL).returncode == 0:
        print(f"error: cannot run {args.modprobe}; install kmod", file=sys.stderr)
        return 2

    symvers = parse_symvers(args.symvers)
    modules = list(iter_modules(args.modules))
    if not modules:
        print(f"error: no .ko files under {args.modules}", file=sys.stderr)
        return 2

    total = matched = 0
    mismatches: list[tuple[str, str, str, str]] = []
    missing: collections.Counter[str] = collections.Counter()
    missing_examples: dict[str, list[str]] = collections.defaultdict(list)

    for module in modules:
        try:
            versions = dump_versions(args.modprobe, module)
        except Exception as exc:  # noqa: BLE001 - report and continue
            print(f"warning: cannot read {module}: {exc}", file=sys.stderr)
            continue
        for symbol, crc in versions.items():
            total += 1
            if symbol in symvers:
                if symvers[symbol] == crc:
                    matched += 1
                else:
                    mismatches.append((module.name, symbol, crc, symvers[symbol]))
            else:
                missing[symbol] += 1
                if len(missing_examples[symbol]) < 3:
                    missing_examples[symbol].append(module.name)

    print(f"modules={len(modules)} symbol_refs={total} matched={matched} "
          f"mismatched={len(mismatches)} missing_from_vmlinux={sum(missing.values())} "
          f"unique_missing={len(missing)}")

    if mismatches:
        print("\nCRC MISMATCHES (fatal):")
        for module, symbol, mod_crc, kernel_crc in mismatches[:50]:
            print(f"  {module}: {symbol} module={mod_crc} kernel={kernel_crc}")
        print("\nResult: FAILED - module CRC mismatch")
        return 1

    print("\nResult: OK - no CRC mismatch")
    if missing:
        print(f"note: {len(missing)} symbols are not in vmlinux; they may be "
              f"exported by other vendor modules.")
        for symbol, count in missing.most_common(args.show_missing):
            print(f"  {count:4d}  {symbol}  e.g. {missing_examples[symbol]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
