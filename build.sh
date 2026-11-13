#!/usr/bin/env bash
# Xiaomi Redmi Note 9T 5G（cannon / MT6853）— TWRP 16.0 一键构建
#
#   ./build.sh doctor   环境体检
#   ./build.sh init     repo init + 安装 local_manifests/cannon.xml
#   ./build.sh sync     repo sync
#   ./build.sh build    lunch twrp_cannon-bp2a-eng + m recoveryimage
#   ./build.sh all      init + sync + build
#
# 环境变量：
#   ROM_DIR          工作区（默认 /cannon/twrp16）
#   JOBS             并行度（默认 nproc）
#   MANIFEST_BRANCH  TWRP-Test 分支（默认 twrp-16.0）
set -euo pipefail

ROM_DIR="${ROM_DIR:-/cannon/twrp16}"
JOBS="${JOBS:-$(nproc)}"
MANIFEST_URL="${MANIFEST_URL:-https://github.com/TWRP-Test/platform_manifest_twrp_aosp}"
MANIFEST_BRANCH="${MANIFEST_BRANCH:-twrp-16.0}"
LUNCH_TARGET="${LUNCH_TARGET:-twrp_cannon-bp2a-eng}"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

cmd_doctor() {
    for c in repo git java python3; do
        command -v "$c" >/dev/null || die "missing: $c"
    done
    [ -d "$ROM_DIR/.repo" ] || echo "warn: $ROM_DIR 还不是 repo 工作区（先 ./build.sh init）"
    echo "ROM_DIR=$ROM_DIR JOBS=$JOBS BRANCH=$MANIFEST_BRANCH LUNCH=$LUNCH_TARGET"
}

cmd_init() {
    mkdir -p "$ROM_DIR"
    cd "$ROM_DIR"
    [ -d .repo ] || repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --depth=1
    mkdir -p .repo/local_manifests
    cp "$SRC_DIR"/local_manifests/*.xml .repo/local_manifests/
    log "local_manifests 已安装：$(ls .repo/local_manifests)"
}

cmd_sync() {
    cd "$ROM_DIR"
    repo sync -j"$JOBS" --force-sync --no-clone-bundle
}

cmd_build() {
    cd "$ROM_DIR"
    export ALLOW_MISSING_DEPENDENCIES=true
    # shellcheck disable=SC1091
    source build/envsetup.sh
    lunch "$LUNCH_TARGET"
    m recoveryimage -j"$JOBS"
    log "产物：$ROM_DIR/out/target/product/cannon/recovery.img"
}

case "${1:-all}" in
    doctor) cmd_doctor ;;
    init)   cmd_init ;;
    sync)   cmd_sync ;;
    build)  cmd_build ;;
    all)    cmd_doctor; cmd_init; cmd_sync; cmd_build ;;
    *)      die "unknown command: $1 (doctor|init|sync|build|all)" ;;
esac