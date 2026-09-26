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
