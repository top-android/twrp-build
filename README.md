# twrp-build

Xiaomi Redmi Note 9T 5G（`cannon`，MT6853）在 **TWRP 16.0（TWRP-Test / YARP `twrp-16.0`）** 上的构建入口。

只覆盖有本地净改动的仓，其余 project（含 `system/vold`）继续跟 TWRP-Test 的 `default.xml`：

> `system/vold` 已核实**相对上游净改动为 0**（`createOperation` 的 `false` 就是上游默认值），不再单独维护。

| 路径 | 仓库 | 关键改动 |
|---|---|---|
| `device/xiaomi/cannong` | `top-android/twrp_device_xiaomi_cannon` | **A17 解密补丁级别**（`PLATFORM_SECURITY_PATCH` 必须等于系统真实值）、gatekeeper `beanpod`、震动 `haptic_pwm` + AW8622 固件、默认中文/UTC+8/24h、代号 `cannon`、OTA assert 绕过、fscrypt v2 |
| `bootable/recovery` | `top-android/twrp_bootable_recovery` | `haptic_pwm` 震动后端、`ro.twrp.boot` 开关、默认 `zh_CN` / `CST-8` / 24h |

## 用法

```bash
git clone https://github.com/top-android/twrp-build.git
cd twrp-build
./build.sh doctor
./build.sh all
```

默认工作区 `/cannon/twrp16`，可用 `ROM_DIR=...` 覆盖；产物在
`$ROM_DIR/out/target/product/cannon/recovery.img`。

单独步骤：`./build.sh init` / `sync` / `check` / `repair` / `build`。

## 同步（浅克隆）

`sync` 固定使用 `--depth=1` + `-c --fail-fast`。若 sync 在 `early EOF` 后原位重试，
repo 可能把该项目当成非浅克隆并拉完整历史（`prebuilts/sdk` 从 1 个 commit / 1.8G
涨到 20582 个 commit / 17.4G）。`sync` 结束会自动执行 `check`：

```bash
./build.sh check    # 列出 shallow 缺失的项目，missing 必须为 0
./build.sh repair   # 删除三处记录后单项目重拉，恢复浅克隆
```

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