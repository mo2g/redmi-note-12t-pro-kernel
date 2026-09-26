# 设备与版本参考

> 本仓库只针对下列组合做过验证；其他 ROM/内核版本请先自行核对源码行号和
> 导出符号，不要直接套用。

| 项目 | 值 |
|---|---|
| 机型 | Redmi Note 12T Pro |
| 型号 | 23054RA19C |
| codename | `pearl` |
| SoC | MediaTek MT6895 / MT6896（天玑 8200 系列） |
| ROM | MIUI 14 / `V14.0.5.0.TLHCNXM` |
| Android | 13（SDK 33） |
| 官方内核 | `5.10.136-android12-9-00020-gc9f59ef34367-ab9585114` |
| 内核构建时间 | 2023-02-08 |
| 源码分支 | `MiCode/Xiaomi_Kernel_OpenSource` `pearl-s-oss` |
| 源码提交 | `d96c1a04b701bcf1d39ed1b8ab4b3137ff6490f9` |
| 修复后版本串示例 | `5.10.136-pearl-cve43499` |
| 前置条件 | bootloader 已解锁；刷入前必须备份 boot 分区 |

## 不包含的内容

- 设备序列号、IMEI/MEID、手机号、账号信息；
- `persist`、`nvram`、`nvdata`、`proinfo`、`efuse`、`lk` 等设备唯一分区；
- 任何个人日志原文、隐藏 Magisk 包名、个人应用/模块列表。

这些内容不属于可公开分发的修复资料，请不要提交到公开仓库。
