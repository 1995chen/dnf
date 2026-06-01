#!/bin/bash

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=./common.sh
source "${SCRIPT_PATH}/common.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

failed=0
pass=0
chk() {
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1))
    else
        printf "FAIL %-44s expected=[%s] got=[%s]\n" "$1" "$2" "$3"
        failed=1
    fi
}
bak_count() { find "$(dirname "$1")" -name "$(basename "$1").*.bak" 2>/dev/null | wc -l; }

# 首次部署，复制模板和真实文件
# 镜像中的原始文件: src
# 持久化目录中的模板文件: ref
# 实际使用的文件: target
d="$WORK/c1"
mkdir -p "$d"
printf 'v1\n' >"$d/src"
msg=$(sync_template_file "$d/src" "$d/t" "$d/ref")
chk "首次部署-msg" "init t success" "$msg"
chk "首次部署-target==ref" "v1" "$(cat "$d/t")"
chk "首次部署-创建 ref" "v1" "$(cat "$d/ref")"

# ref == src: 持久化的文件版本已经是镜像中的最新版
msg=$(sync_template_file "$d/src" "$d/t" "$d/ref")
chk "已是最新版本-msg" "t have already inited, do nothing!" "$msg"
chk "已是最新版本-无需备份现有文件" 0 "$(bak_count "$d/t")"

# target == ref 但 target != ref: 说明用户没有修改过文件，但版本不是最新。无需备份用户文件，直接升级
d="$WORK/c3"
mkdir -p "$d"
printf 'old\n' >"$d/t"
printf 'old\n' >"$d/ref"
printf 'new\n' >"$d/src"
msg=$(sync_template_file "$d/src" "$d/t" "$d/ref")
chk "旧模板升级-msg" "regenerate t: template updated" "$msg"
chk "旧模板升级-target==new ref" "new" "$(cat "$d/t")"
chk "旧模板升级-无需备份现有文件" 0 "$(bak_count "$d/t")"

# ref != src，且 target != ref，说明镜像已经更新了，且用户基于旧版本做了一些自定义修改，先备份用户的文件, 再覆盖新模板
d="$WORK/c4"
mkdir -p "$d"
printf 'user-edit\n' >"$d/t"
printf 'tpl-v1\n' >"$d/ref"
printf 'tpl-v2\n' >"$d/src"
msg=$(sync_template_file "$d/src" "$d/t" "$d/ref")
chk "用户自定义-msg" yes "$(echo "$msg" | grep -q "backup customized t" && echo yes || echo no)"
chk "旧版本用户自定义-生成备份" 1 "$(bak_count "$d/t")"
chk "旧版本用户自定义-备份内容" "user-edit" "$(cat "$d"/t.*.bak)"
chk "旧版本用户自定义-target更新为新版本" "tpl-v2" "$(cat "$d/t")"
chk "旧版本用户自定义-ref更新为新版本" "tpl-v2" "$(cat "$d/ref")"

# target 存在，但 ref 不存在，且 target != src: 先备份再覆盖
d="$WORK/c5"
mkdir -p "$d"
printf 'legacy\n' >"$d/t"
printf 'tpl\n' >"$d/src"
sync_template_file "$d/src" "$d/t" "$d/ref" >/dev/null
chk "迁移-生成备份" 1 "$(bak_count "$d/t")"
chk "迁移-备份旧文件" "legacy" "$(cat "$d"/t.*.bak)"
chk "迁移-target==src" "tpl" "$(cat "$d/t")"

# target == src，但 ref 不存在: 不备份target, 只复制 ref
d="$WORK/c6"
mkdir -p "$d"
printf 'same\n' >"$d/t"
printf 'same\n' >"$d/src"
sync_template_file "$d/src" "$d/t" "$d/ref" >/dev/null
chk "target已最新但ref不存在-无需备份" 0 "$(bak_count "$d/t")"
chk "target已最新但ref不存在-复制ref" "same" "$(cat "$d/ref")"

# target == src 但 ref != target 目标==模板: 说明用户可能手动升级过版本，但忘记升级 ref 了，不备份target, 只更新 ref 为最新版本
d="$WORK/c7"
mkdir -p "$d"
printf 'latest\n' >"$d/t"
printf 'latest\n' >"$d/src"
printf 'stale-ref\n' >"$d/ref"
msg=$(sync_template_file "$d/src" "$d/t" "$d/ref")
chk "target已是最新但ref为旧版本-msg" "t have already inited, do nothing!" "$msg"
chk "target已是最新但ref为旧版本-无需备份" 0 "$(bak_count "$d/t")"
chk "target已是最新但ref为旧版本-target保持不变" "latest" "$(cat "$d/t")"
chk "target已是最新但ref为旧版本-更新ref" "latest" "$(cat "$d/ref")"

# src == ref 但 target != ref，说明用户基于最新版本做了一些自定义修改：无需做任何操作
d="$WORK/c8"
mkdir -p "$d"
printf 'my-custom\n' >"$d/t"
printf 'tpl\n' >"$d/ref"
printf 'tpl\n' >"$d/src"
msg=$(sync_template_file "$d/src" "$d/t" "$d/ref")
chk "基于最新版本自定义-msg" "keep customized t, not overwritten" "$msg"
chk "基于最新版本自定义-无需备份" 0 "$(bak_count "$d/t")"
chk "基于最新版本自定义-target保持不变" "my-custom" "$(cat "$d/t")"

# substitute_port_markers: 将文件中标记替换为对应环境变量值, 未知标记保持不变
spm="$WORK/spm.cfg"
printf 'a=__AUCTION_TCP_PORT__\nb=__COSERVER_UDP_PORT__\nc=__MAIN_DB_PROXY_PORT__\nd=__CHANNEL_TCP_PORT__\nkeep=__UNKNOWN_TOKEN__\n' >"$spm"
AUCTION_TCP_PORT=30803 COSERVER_UDP_PORT=30703 MAIN_DB_PROXY_PORT=3307 CHANNEL_TCP_PORT=7001 \
    substitute_port_markers "$spm"
chk "端口替换 auction" "a=30803" "$(grep '^a=' "$spm")"
chk "端口替换 coserver" "b=30703" "$(grep '^b=' "$spm")"
chk "端口替换 proxy" "c=3307" "$(grep '^c=' "$spm")"
chk "端口替换 channel" "d=7001" "$(grep '^d=' "$spm")"
chk "未知标记保持不变" "keep=__UNKNOWN_TOKEN__" "$(grep '^keep=' "$spm")"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
