# redmi-note-12t-pro-kernel

**English** | [简体中文](README.zh-CN.md)

Unofficial kernel patches, security fixes, and tooling for the **Redmi Note 12T Pro** (codename `pearl`, MediaTek MT6895/MT6896).

Current focus: **CVE-2026-43499** in the official MIUI 14 / 5.10.136 kernel.

> **Disclaimer**: This project is not affiliated with Xiaomi, Redmi, or MediaTek. Flashing a kernel can brick your device. It is intended only for a `pearl` device with a matching ROM/kernel version. Back up your boot partition before flashing; you are responsible for your own device.

## Current fixes

| Fix | Patches | Status |
|---|---|---|
| CVE-2026-43499: `rtmutex` `remove_waiter()` UAF | Official 5.10.260 backports `f3fa3424` + `bfbc047c` | Patches, build, verification, and rollback guides provided |

> Convention for future fixes: add patches to `patches/` with increasing numbers, update this table and `CHANGELOG.md`, and attach the build artifacts, SHA256, and applicability notes to the corresponding GitHub Release.

## Background

- **Affected environment**: official MIUI `V14.0.5.0.TLHCNXM`, Android 13, kernel `5.10.136` (built 2023-02-08).
- **Vulnerability**: in `kernel/locking/rtmutex.c`, `remove_waiter()` incorrectly uses `current` instead of `waiter->task` in the rollback path of `rt_mutex_start_proxy_lock()`. This leaves a dangling `pi_blocked_on` pointer, a use-after-free (UAF).
- **Trigger paths**: PI futex / `FUTEX_CMP_REQUEUE_PI` paths involving `futex_requeue()`. Go-runtime network applications, system services, and call/audio paths can generate related calls.
- **Possible symptoms**:
  - Direct Oops: `futex_requeue → put_pi_state`;
  - A silent hang during call/audio setup followed by a cold reset;
  - Because the bug corrupts kernel memory, crashes may also appear in unrelated subsystems.
- **Upstream fix**:
  - mainline `3bfdc63936dd` (2026-04-21);
  - 5.10 stable backports `f3fa3424` + `bfbc047c`, released with **Linux 5.10.260** (2026-07).
- **Relationship to unlocked bootloader / Magisk**:
  Unlocking the bootloader does not modify the kernel; Magisk patches the boot ramdisk only. On the target device, the kernel binary segments of the Magisk-patched and unpatched boot images were byte-identical. Root/Go workloads can increase the trigger probability, but they are not the root cause.

## Repository layout

```text
.
├── README.md                          # English (default)
├── README.zh-CN.md                    # Chinese
├── configs/device_kconfig.txt          # kernel config exported from the device
├── docs/
│   ├── root-cause.md                    # vulnerability details and references
│   ├── build-guide.md                   # build + pack instructions
│   ├── verification.md                  # pre/post-flash checks
│   ├── rollback.md                      # backup and rollback
│   ├── case-study-reboots.md            # sanitized reboot case study
│   ├── device-reference.md              # device/ROM/kernel reference (no serial)
│   └── release-process.md               # automated release details
├── patches/
│   ├── 0001-rtmutex-use-waiter-task-in-remove_waiter.patch
│   └── 0002-rtmutex-skip-remove_waiter-when-not-enqueued.patch
├── scripts/
│   ├── build-kernel.sh                  # helper build script
│   ├── pack-boot.sh                     # replace kernel with magiskboot, keep ramdisk
│   └── prepare-release-assets.sh        # create release assets + checksums
├── tools/
│   ├── check_kernel.sh                  # detect whether the fix is present
│   ├── ghostlock-extract                # upstream detector (macOS arm64 convenience binary)
│   ├── module-crc-check.py              # vendor module CRC compatibility checker
│   └── README.md
└── .github/workflows/
    ├── patch-check.yml                  # CI: verify patches apply cleanly
    └── release.yml                      # CI: tag-triggered release build
```

## Quick start

### 1. Detect the current kernel

```bash
tools/check_kernel.sh
```

- Requires adb with root (`su` granted to the shell).
- Read-only; it does not write to the device.
- It reports **fixed** only when `remove_waiter()` no longer reads `current`.

You can also check a specific boot image:

```bash
tools/check_kernel.sh /path/to/boot.img
```

### 2. Build the fixed kernel

See [`docs/build-guide.md`](docs/build-guide.md). High-level steps:

1. Fetch the official `pearl-s-oss` source at commit `d96c1a04b701bcf1d39ed1b8ab4b3137ff6490f9` (5.10.136).
2. Apply the two 5.10.260 backports in `patches/` in order.
3. Use `configs/device_kconfig.txt` as the baseline config.
4. Build `Image` / `Image.gz` with clang 12 + LLVM/LLD (on x86_64 hosts, `scripts/build-kernel.sh` sets `CROSS_COMPILE=aarch64-linux-gnu-` automatically).
5. Replace the kernel in your own Magisk-patched boot image with `magiskboot`; keep the ramdisk.
6. Verify the new boot image with `tools/check_kernel.sh` before flashing.

### 3. Verify, pack, flash, roll back

- [`docs/verification.md`](docs/verification.md) — pre/post-flash checklist.
- [`docs/rollback.md`](docs/rollback.md) — boot backup, fastboot rollback, root `dd` rollback.
- [`scripts/pack-boot.sh`](scripts/pack-boot.sh) — repack your own boot image with the new kernel and keep Magisk.
- **Always back up your original boot partition before flashing.** This repository does not contain any device-unique partition backups.

## Automated releases

The repository includes [`.github/workflows/release.yml`](.github/workflows/release.yml):

- Pushing a `v*` tag (for example `v1.0.0-cve-2026-43499`) triggers GitHub Actions to:
  1. download the pinned official `pearl-s-oss` source;
  2. apply the two patches;
  3. build with ThinLTO + CFI + Shadow Call Stack + MODVERSIONS;
  4. verify the fix with the upstream GhostLock detector;
  5. publish a GitHub Release with checksums.
- Release assets (kernel-only):
  - `redmi-note-12t-pro-kernel-<tag>-Image.gz`
  - `redmi-note-12t-pro-kernel-<tag>-Image`
  - `redmi-note-12t-pro-kernel-<tag>-Module.symvers`
  - `redmi-note-12t-pro-kernel-<tag>-device_kconfig.patched`
  - `build-info.txt`
  - `SHA256SUMS`
- **Important**: the automated release does **not** include a ready-to-flash `boot.img`. A boot image also contains a ROM- and Magisk-specific ramdisk. Download the kernel assets and repack them into **your own** boot backup using [`scripts/pack-boot.sh`](scripts/pack-boot.sh). See [`docs/release-process.md`](docs/release-process.md).

Trigger the first release:

```bash
git tag v1.0.0-cve-2026-43499
git push origin v1.0.0-cve-2026-43499
```

## Verified results (target device)

- Running kernel: `5.10.136-pearl-cve43499`
- `tools/check_kernel.sh`: **fixed** — `remove_waiter()` no longer reads `current`
- Vendor module CRC check: 228 modules, 13,118 symbol references, **11,397 matched / 0 mismatched**
- Post-flash: Magisk root, Wi-Fi, Bluetooth, touch, cameras (5), fingerprint HAL, GPS, audio, and telephony all worked

> The verification build used **ThinLTO** to avoid an OOM during FULL LTO linking on a low-memory builder, while keeping `CFI_CLANG`, `SHADOW_CALL_STACK`, and `MODVERSIONS`.
> To reproduce the stock `FULL LTO` build, enable `CONFIG_LTO_CLANG_FULL=y` and build on a Linux machine with at least 8–12 GB of RAM.

## Privacy and publishing rules

Do **not** commit:

- `backup/` — `persist`, `nvram`, `nvdata`, `proinfo`, `efuse`, `lk`, `vbmeta`, `boot`, and other device-unique/proprietary partitions;
- `device_info.txt` — contains the device serial number;
- `kernel-build/out/` — `vmlinux`, build logs, `Module.symvers`, `new-boot.img`, and other large build artifacts;
- the Xiaomi source tarball (about 200 MB; fetch it from the official repository);
- reports with personal app lists, hidden Magisk package names, accounts, phone numbers, or raw personal logs.

See [`RELEASE-CHECKLIST.md`](RELEASE-CHECKLIST.md) before publishing.

## License and credits

- The patches are based on the Linux kernel stable tree (GPL-2.0-only); the source comes from Xiaomi Kernel Open Source (GPL-2.0).
- If prebuilt boot images are distributed via GitHub Releases, comply with Magisk (GPL-3.0) and include the corresponding source/patches and build instructions.
- `tools/ghostlock-extract` comes from [YuKongA/ghostlock-app](https://github.com/YuKongA/ghostlock-app), Apache-2.0.
- This repository's documentation and scripts are released under **GPL-2.0-only**. See [`LICENSE`](LICENSE) and [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Repository naming

`pearl` is the internal codename; the marketing name is **Redmi Note 12T Pro**. The repository is intentionally named `redmi-note-12t-pro-kernel` so ordinary users can find it by the marketing name, while `pearl` remains in the description, topics, and README for users who know the codename. Specific CVEs are tracked in this README, `CHANGELOG.md`, topics, and GitHub Releases rather than in the repository name.

> Detailed guides under `docs/` are currently written primarily in Chinese. English translations and corrections are welcome.
