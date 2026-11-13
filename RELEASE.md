# TWRP 16.0 (YARP) — Xiaomi Redmi Note 9T 5G

| 项 | 内容 |
|---|---|
| 设备 | Xiaomi Redmi Note 9T 5G（`cannon` / `cannong`，MT6853） |
| 版本 | TWRP 16.0（TWRP-Test / YARP `twrp-16.0`） |
| 系统 | Android 17 / LineageOS 24.0，向下兼容 Android 16 / 15 |
| 镜像 | `recovery.img` — md5 `4780539593f6862f23cf3796176ac75d` |

## 状态

功能完备，无阻塞性或功能性 bug。已知外观瑕疵：

- 启动 logo 结束后整屏白闪一下（GUI2 首次绘制时序，不影响使用）
- 深色主题下状态栏顶部偶见一条白线；推荐使用默认浅色主题

## 功能

- **解密 `/data`**：Android 17（LineageOS 24.0）metadata + FBE 解密，向下兼容 A16 / A15
- **震动**：MTK `haptic_pwm` 后端（`/sys/devices/platform/haptic_pwm`）+ AW8622 固件
- **USB OTG**：U 盘热插拔，自动识别 vfat / exfat / ntfs
- **真实电量**：容量与充电状态；health HAL 不可用时直接读
  `/sys/class/power_supply/battery/{capacity,status}`
- **状态栏时钟**：默认显示秒（设置 → 时间和时区可关闭），24 小时制，已避开左上摄像头挖孔
- **中文环境**：默认 `zh_CN`、`CST-8`、24 小时制
- **OTA 包**：编译期绕过 device / version assert（`ro.twrp.boot` 开关）
- **设备代号**：`cannon`（设备树目录沿用 `cannong`，软链接兼容）
- **A/B 空 slot**：`ro.boot.slot_suffix` 为空时跳过 `SetActiveSlot`，不再报错
- **常规能力**：备份 / 恢复、安装 zip / img、文件管理、终端、MTP、ADB、Sideload、
  Wipe / Format Data、分区挂载

## 兼容性

| 系统 | 状态 |
|---|---|
| LineageOS 24.0（Android 17） | 主要目标，已实测 |
| LineageOS 23.2（Android 16） | 向下兼容 |
| 其它 A15 / A16 / A17 ROM | 可用，但需同步补丁级别（见下） |

解密依赖设备树中的补丁级别与系统一致：

```make
PLATFORM_SECURITY_PATCH := 2026-11-01
VENDOR_SECURITY_PATCH   := 2021-11-05
```

系统安全补丁升级后需同步修改这两个值并重编。写成 `2099-12-31` 会让密钥环境比 blob 新，
解密报 `BeginOperation -62` / `UpgradeKey -38`。

## 安装

```bash
fastboot flash recovery recovery.img
```

本机为 A-only 分区，直接刷入 recovery 分区即可。

## 升级与降级

- **升级**（A16 → A17）：直接刷入本 recovery，再刷 ROM
- **降级**（A17 → A16）：A16 读不了 A17 的 spblob / CE key，**必须先清除加密数据**：

  ```bash
  fastboot erase userdata
  fastboot erase metadata
  ```

  也可以在官方 recovery 里执行 Factory reset。之后刷入 A16 ROM，首次开机完成，
  再刷回对应版本的 TWRP。

## 构建

```bash
git clone https://github.com/top-android/twrp-build.git
cd twrp-build
./build.sh doctor
./build.sh all          # init + sync + build
```

单独步骤：`./build.sh init` / `sync` / `check` / `repair` / `build`。
产物：`out/target/product/cannon/recovery.img`。

需要从零精确复现本镜像时，用快照 manifest（所有项目固定到 commit）：

```bash
./build.sh init-pin    # 空目录；repo init -m local_manifests/cannon-snapshot.xml
./build.sh sync
./build.sh build
```

同步固定使用 `--depth=1` + `-c --fail-fast`；若 `early EOF` 后重试导致某个项目退化成
完整历史，`sync` 结束会自动 `check`，用 `./build.sh repair` 单项目重拉恢复浅克隆。

## 对应源码

| 路径 | 仓库 | 提交 |
|---|---|---|
| `device/xiaomi/cannong` | `top-android/twrp_device_xiaomi_cannon` | `1c63a5a` |
| `bootable/recovery` | `top-android/twrp_bootable_recovery` | `0890093` |
| `local_manifests/cannon.xml` | `top-android/twrp-build` | 本仓 |