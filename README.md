# twrp-build

Xiaomi Redmi Note 9T 5G（`cannon`，MT6853）在 **TWRP 16.0（TWRP-Test / YARP `twrp-16.0`）** 上的构建入口。

只覆盖三个有本地修改的仓，其余 project 继续跟 TWRP-Test 的 `default.xml`：

| 路径 | 仓库 | 关键改动 |
|---|---|---|
| `device/xiaomi/cannong` | `top-android/twrp_device_xiaomi_cannon` | **A17 解密补丁级别**（`PLATFORM_SECURITY_PATCH` 必须等于系统真实值）、gatekeeper `beanpod`、震动 `haptic_pwm` + AW8622 固件、默认中文/UTC+8/24h、代号 `cannon`、OTA assert 绕过、fscrypt v2 |
| `bootable/recovery` | `top-android/twrp_bootable_recovery` | `haptic_pwm` 震动后端、`ro.twrp.boot` 开关、默认 `zh_CN` / `CST-8` / 24h |
| `system/vold` | `top-android/twrp_system_vold` | 保持 AOSP16 `createOperation(false)`（`true` 会导致卡 logo 循环） |

## 用法

```bash
git clone https://github.com/top-android/twrp-build.git
cd twrp-build
./build.sh doctor
./build.sh all
```

默认工作区 `/cannon/twrp16`，可用 `ROM_DIR=...` 覆盖；产物在
`$ROM_DIR/out/target/product/cannon/recovery.img`。

单独步骤：`./build.sh init` / `sync` / `build`。

## A17 解密必读

TWRP 解 LineageOS 24（A17）的 `/data` 报 `Unable to decrypt metadata encryption`、
logcat 里 `BeginOperation -62` / `UpgradeKey -38` 时，**先查设备树补丁级别**：

```make
PLATFORM_SECURITY_PATCH := <系统 getprop ro.build.version.security_patch 的值>
VENDOR_SECURITY_PATCH   := <系统 getprop ro.vendor.build.security_patch 的值>
```

写成 `2099-12-31` 会让 keymaster 认为 recovery 环境比密钥 blob 新，反复要求升级。
本机实测值：`2026-11-01` / `2021-11-05`。系统安全补丁升级后要同步更新。

完整排查记录见 `cannon-port-log` 的 `docs/playbooks/A17_TWRP_CANNON_PORT.md`
（「2026-11-13 收尾」章节）。

## 内核

`prebuilt/Image.gz` 使用**无 KSU** 版本。KSU/SUSFS 内核的 hang 30s 会让 recovery 定时重启，
且与解密无关。