# Changelog

## v1.0.0 (2026-09-26)

- Initial release.
- Add official Linux 5.10.260 backports for CVE-2026-43499:
  - `f3fa3424` rtmutex: use `waiter::task` instead of `current`
  - `bfbc047c` rtmutex: skip `remove_waiter()` when waiter is not enqueued
- Add device kernel config (`configs/device_kconfig.txt`).
- Add build/pack/verify/rollback guides and helper scripts.
- Add `check_kernel.sh`, `ghostlock-extract` convenience binary, and
  `module-crc-check.py`.
- Add sanitized reboot case study.
- Add bilingual README: `README.md` (English, default) and `README.zh-CN.md` (Chinese).
- First automated release published: [v1.0.0-cve-2026-43499](https://github.com/mo2g/redmi-note-12t-pro-kernel/releases/tag/v1.0.0-cve-2026-43499)
- Add tag-triggered GitHub Actions release workflow (`.github/workflows/release.yml`)
  that publishes kernel-only assets (`Image`, `Image.gz`, `Module.symvers`, config,
  build info, SHA256SUMS). Ready-to-flash `boot.img` is intentionally not published.

> Repository naming: `redmi-note-12t-pro-kernel` is intentionally broad so future
> kernel patches, security fixes, and tools can be added under the same repository.
> CVE-specific details live in the README, `CHANGELOG.md`, topics, and GitHub Releases.
