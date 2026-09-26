# Third-Party Notices

This repository contains or references third-party components. Please keep the
following notices when redistributing source or binaries.

## Linux kernel stable patches

Files:

- `patches/0001-rtmutex-use-waiter-task-in-remove_waiter.patch`
- `patches/0002-rtmutex-skip-remove_waiter-when-not-enqueued.patch`

Origin: Linux kernel stable tree (`gregkh/linux`, `linux-5.10.y`), commits
`f3fa3424bceb128d2be4b3745506b22844b87db7` and
`bfbc047ceb42c0e1fac8f3a155d4548a8bbe76b1`, which backport mainline commit
`3bfdc63936dd4773109b7b8c280c0f3b5ae7d349`.

License: GPL-2.0-only. See `LICENSE`.

## Xiaomi Kernel Open Source

Source used for the build guide:

- Repository: `MiCode/Xiaomi_Kernel_OpenSource`
- Branch/commit: `pearl-s-oss` @ `d96c1a04b701bcf1d39ed1b8ab4b3137ff6490f9`
- Kernel: Linux 5.10.136

License: GPL-2.0. This repository does not redistribute the full Xiaomi source
tree; users should fetch it from the official repository.

## Magisk

If a prebuilt boot image is distributed through GitHub Releases, it may contain
Magisk-patched ramdisk components.

- Project: https://github.com/topjohnwu/Magisk
- License: GPL-3.0 (Magisk is free software; see the upstream repository for the
  full license and source).

## ghostlock-app / ghostlock-extract

- Project: https://github.com/YuKongA/ghostlock-app
- File included for convenience: `tools/ghostlock-extract` (macOS arm64 build)
- License: Apache-2.0

The binary is included only as a defensive kernel-inspection helper. Linux users
should build it from the upstream source; see `tools/README.md`.
