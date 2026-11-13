#!/usr/bin/env bash
# Xiaomi Redmi Note 9T 5G（cannon / MT6853）— TWRP 16.0 一键构建
#
#   ./build.sh doctor   环境体检
#   ./build.sh init     repo init + 安装 local_manifests/cannon.xml
#   ./build.sh sync     repo sync（浅克隆，失败后自动校验）
#   ./build.sh check    校验每个项目是否仍是浅克隆
#   ./build.sh repair   对浅克隆退化的项目删除后单项目重拉
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
    local depth
    depth="$(git -C .repo/manifests.git config --get repo.depth 2>/dev/null || true)"
    [ "$depth" = "1" ] || die "工作区不是浅克隆（repo.depth=${depth:-unset}），请重建 .repo"
    mkdir -p .repo/local_manifests
    cp "$SRC_DIR"/local_manifests/*.xml .repo/local_manifests/
    log "local_manifests 已安装：$(ls .repo/local_manifests)"
}

cmd_sync() {
    cd "$ROM_DIR"
    # Check before syncing: an interrupted fetch leaves a project without a
    # shallow file, and syncing it again is exactly what pulls the full history.
    cmd_check
    # -c/--fail-fast keep every project at --depth=1. Without them a retry after
    # an "early EOF" leaves a non-shallow project behind and refetches its full
    # history (prebuilts/sdk: 1 commit vs 20582, 1.8G vs 17.4G).
    if ! repo sync -j"$JOBS" -c --fail-fast --force-sync --no-clone-bundle; then
        die "repo sync 失败；先运行 ./build.sh check，必要时 ./build.sh repair"
    fi
    cmd_check
}

cmd_check() {
    cd "$ROM_DIR"
    [ -d .repo ] || die "不是 repo 工作区：$ROM_DIR"
    local total=0 missing=0
    while IFS= read -r gitdir; do
        total=$((total + 1))
        if [ ! -f "$gitdir/shallow" ]; then
            echo "MISSING: $gitdir"
            missing=$((missing + 1))
        fi
    done < <(find .repo/projects -name '*.git' -type d)
    echo "projects=$total missing=$missing"
    if [ "$missing" -ne 0 ]; then
        die "有项目退化成完整历史：运行 ./build.sh repair"
    fi
}

cmd_repair() {
    cd "$ROM_DIR"
    [ -d .repo ] || die "不是 repo 工作区：$ROM_DIR"
    local broken=()
    while IFS= read -r gitdir; do
        [ -f "$gitdir/shallow" ] || broken+=("$gitdir")
    done < <(find .repo/projects -name '*.git' -type d)
    [ "${#broken[@]}" -gt 0 ] || { log "所有项目仍是浅克隆，无需修复"; return; }

    for gitdir in "${broken[@]}"; do
        local path="${gitdir#.repo/projects/}"
        path="${path%.git}"
        local name
        name="$(git -C "$gitdir" config --get-regexp '^remote\..*\.projectname$' |
            head -1 | awk '{print $2}')" || true
        log "修复 $path（${name:-unknown}）"
        # Removing all three records makes repo treat the project as new, so the
        # refetch honours --depth=1 instead of pulling the full history.
        rm -rf "$gitdir"
        [ -n "$name" ] && rm -rf ".repo/project-objects/$name.git"
        rm -rf "$path"
        repo sync -j1 --fail-fast -c --no-tags --no-clone-bundle "$path" ||
            die "重拉失败：$path"
    done
    cmd_check
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
    check)  cmd_check ;;
    repair) cmd_repair ;;
    build)  cmd_build ;;
    all)    cmd_doctor; cmd_init; cmd_sync; cmd_build ;;
    *)      die "unknown command: $1 (doctor|init|sync|check|repair|build|all)" ;;
esac