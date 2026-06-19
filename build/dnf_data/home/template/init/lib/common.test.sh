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

# build_neople_tree: 大文件为指向 src 的软链接，小文件为真实文件
bnt_src="$WORK/bnt/src"
bnt_dst="$WORK/bnt/dst"
mkdir -p "$bnt_src/cfg" "$bnt_src/empty"
printf 'cfg-data\n' >"$bnt_src/cfg/a.cfg"
printf '%0100d' 0 >"$bnt_src/big.bin"
printf '#!/bin/sh\necho hi\n' >"$bnt_src/run.sh"
chmod 755 "$bnt_src/run.sh"
mkdir -p "$bnt_dst/empty" "$bnt_dst/cfg"
printf 'mounted-log\n' >"$bnt_dst/empty/live.log"
printf 'STALE\n' >"$bnt_dst/cfg/a.cfg"
printf 'STALE\n' >"$bnt_dst/big.bin"
build_neople_tree "$bnt_src" "$bnt_dst" 64
chk "bnt: 小文件为真实文件" "no" "$([ -L "$bnt_dst/cfg/a.cfg" ] && echo yes || echo no)"
chk "bnt: template 文件覆盖旧文件" "cfg-data" "$(cat "$bnt_dst/cfg/a.cfg" 2>/dev/null)"
chk "bnt: 大文件为软链接" "yes" "$([ -L "$bnt_dst/big.bin" ] && echo yes || echo no)"
chk "bnt: 旧文件被替换为软链接" "$bnt_src/big.bin" "$(readlink "$bnt_dst/big.bin")"
chk "bnt: 软链接可读到源内容" "$(cat "$bnt_src/big.bin")" "$(cat "$bnt_dst/big.bin" 2>/dev/null)"
chk "bnt: 目录为真实目录" "yes" "$([ -d "$bnt_dst/cfg" ] && [ ! -L "$bnt_dst/cfg" ] && echo yes || echo no)"
chk "bnt: 保留可执行权限" "yes" "$([ -x "$bnt_dst/run.sh" ] && echo yes || echo no)"
chk "bnt: template 中不存在的文件应保留" "mounted-log" "$(cat "$bnt_dst/empty/live.log" 2>/dev/null)"

envchg_src="$WORK/envchg/src"
envchg_dst="$WORK/envchg/dst"
mkdir -p "$envchg_src"
printf 'grp=__SERVER_GROUP__\n' >"$envchg_src/x.cfg"
build_neople_tree "$envchg_src" "$envchg_dst"
safe_sed "__SERVER_GROUP__" "3" "$envchg_dst/x.cfg"
chk "envchg: 首次替换为 3" "grp=3" "$(cat "$envchg_dst/x.cfg" 2>/dev/null)"
build_neople_tree "$envchg_src" "$envchg_dst"
safe_sed "__SERVER_GROUP__" "5" "$envchg_dst/x.cfg"
chk "envchg: 改环境变量再次运行后替换为 5" "grp=5" "$(cat "$envchg_dst/x.cfg" 2>/dev/null)"
chk "envchg: 旧配置应被清除" "no" "$(grep -q '^grp=3' "$envchg_dst/x.cfg" && echo yes || echo no)"

# build_neople_tree: 小于阈值的文件应复制
bnt_src2="$WORK/bnt2/src"
bnt_dst2="$WORK/bnt2/dst"
mkdir -p "$bnt_src2"
printf 'tiny\n' >"$bnt_src2/t"
build_neople_tree "$bnt_src2" "$bnt_dst2"
chk "bnt: 小于阈值的文件使用复制" "no" "$([ -L "$bnt_dst2/t" ] && echo yes || echo no)"
chk "bnt: 小于阈值的文件复制后内容正确" "tiny" "$(cat "$bnt_dst2/t" 2>/dev/null)"

# build_neople_tree: 已经存在的软链接若因体积变小后小于阈值，应使用复制
bnt3_src="$WORK/bnt3/src"
bnt3_dst="$WORK/bnt3/dst"
mkdir -p "$bnt3_src" "$bnt3_dst"
printf 'new-content\n' >"$bnt3_src/x"
printf 'sentinel-content\n' >"$WORK/bnt3/sentinel"
ln -s "$WORK/bnt3/sentinel" "$bnt3_dst/x"
build_neople_tree "$bnt3_src" "$bnt3_dst"
chk "bnt: 旧软链转文件" "no" "$([ -L "$bnt3_dst/x" ] && echo yes || echo no)"
chk "bnt: 旧软链转文件-内容正确" "new-content" "$(cat "$bnt3_dst/x" 2>/dev/null)"
chk "bnt: 旧软链转文件-源文件内容不受影响" "sentinel-content" "$(cat "$WORK/bnt3/sentinel" 2>/dev/null)"

# build_neople_tree: 配置类文件使用复制
bnt4_src="$WORK/bnt4/src"
bnt4_dst="$WORK/bnt4/dst"
mkdir -p "$bnt4_src/cfg"
dd if=/dev/zero of="$bnt4_src/cfg/big.cfg" bs=1024 count=8 2>/dev/null
dd if=/dev/zero of="$bnt4_src/big.xml" bs=1024 count=8 2>/dev/null
dd if=/dev/zero of="$bnt4_src/big.bin" bs=1024 count=8 2>/dev/null
build_neople_tree "$bnt4_src" "$bnt4_dst" 64
chk "bnt: 大 cfg 文件仍使用复制" "no" "$([ -L "$bnt4_dst/cfg/big.cfg" ] && echo yes || echo no)"
chk "bnt: 大 xml 文件仍使用复制" "no" "$([ -L "$bnt4_dst/big.xml" ] && echo yes || echo no)"
chk "bnt: 其他大文件使用软链接" "yes" "$([ -L "$bnt4_dst/big.bin" ] && echo yes || echo no)"

# build_neople_tree: 未知类型小文件处理
bnt5_src="$WORK/bnt5/src"
bnt5_dst="$WORK/bnt5/dst"
mkdir -p "$bnt5_src"
printf 'x' >"$bnt5_src/small.unknown"
dd if=/dev/zero of="$bnt5_src/big.unknown" bs=1024 count=600 2>/dev/null
build_neople_tree "$bnt5_src" "$bnt5_dst"
chk "bnt: 未知小文件使用复制" "no" "$([ -L "$bnt5_dst/small.unknown" ] && echo yes || echo no)"
chk "bnt: 未知大文件使用软链接" "yes" "$([ -L "$bnt5_dst/big.unknown" ] && echo yes || echo no)"

# build_neople_tree: 只读文件无视大小一律使用软链接
bnt6_src="$WORK/bnt6/src"
bnt6_dst="$WORK/bnt6/dst"
mkdir -p "$bnt6_src"
printf 'x' >"$bnt6_src/df_relay_r"
printf 'x' >"$bnt6_src/a.dib"
printf 'x' >"$bnt6_src/libx.so.1.0.2"
printf 'x' >"$bnt6_src/game.exe"
printf 'x' >"$bnt6_src/iteminfo.dat"
printf 'x' >"$bnt6_src/channel_info.etc"
build_neople_tree "$bnt6_src" "$bnt6_dst"
chk "bnt: df_* 文件使用软链接" "yes" "$([ -L "$bnt6_dst/df_relay_r" ] && echo yes || echo no)"
chk "bnt: .dib 文件使用软链接" "yes" "$([ -L "$bnt6_dst/a.dib" ] && echo yes || echo no)"
chk "bnt: .so 文件使用软链接" "yes" "$([ -L "$bnt6_dst/libx.so.1.0.2" ] && echo yes || echo no)"
chk "bnt: .exe 文件使用软链接" "yes" "$([ -L "$bnt6_dst/game.exe" ] && echo yes || echo no)"
chk "bnt: iteminfo.dat 使用复制" "no" "$([ -L "$bnt6_dst/iteminfo.dat" ] && echo yes || echo no)"
chk "bnt: channel_info.etc 使用复制" "no" "$([ -L "$bnt6_dst/channel_info.etc" ] && echo yes || echo no)"

# build_neople_tree: 阈值边界测试，等于阈值使用软链接, 小一字节就使用复制
bnt7_src="$WORK/bnt7/src"
bnt7_dst="$WORK/bnt7/dst"
mkdir -p "$bnt7_src"
dd if=/dev/zero of="$bnt7_src/at" bs=524288 count=1 2>/dev/null
dd if=/dev/zero of="$bnt7_src/below" bs=524287 count=1 2>/dev/null
build_neople_tree "$bnt7_src" "$bnt7_dst"
chk "bnt: 大小等于阈值的文件使用软链接" "yes" "$([ -L "$bnt7_dst/at" ] && echo yes || echo no)"
chk "bnt: 小于阈值一字节的文件就复制" "no" "$([ -L "$bnt7_dst/below" ] && echo yes || echo no)"

# build_neople_tree: 模板中的软链接与特殊文件按原样复制, 保留软链接与文件类型
bnt8_src="$WORK/bnt8/src"
bnt8_dst="$WORK/bnt8/dst"
mkdir -p "$bnt8_src"
ln -s /dev/null "$bnt8_src/oddlink"
mkfifo "$bnt8_src/myfifo"
build_neople_tree "$bnt8_src" "$bnt8_dst"
chk "bnt: 模板软链接复制为软链接" "yes" "$([ -L "$bnt8_dst/oddlink" ] && echo yes || echo no)"
chk "bnt: 软链接目标保持一致" "/dev/null" "$(readlink "$bnt8_dst/oddlink")"
chk "bnt: fifo 特殊文件原样复制" "yes" "$([ -p "$bnt8_dst/myfifo" ] && echo yes || echo no)"

# enumerate_open_channels: 解析频道编号
chk "ocl: 普通列表" "11 52" "$(enumerate_open_channels '11,52' | tr '\n' ' ' | sed 's/ $//')"
chk "ocl: 区间列表" "11 12 13" "$(enumerate_open_channels '11-13' | tr '\n' ' ' | sed 's/ $//')"
chk "ocl: 列表与区间混合" "1 6 7 11 12" "$(enumerate_open_channels '1,6,7,11-12' | tr '\n' ' ' | sed 's/ $//')"
chk "ocl: 过滤非法频道号" "1 11" "$(enumerate_open_channels '1,8,40,11,99' | tr '\n' ' ' | sed 's/ $//')"
chk "ocl: 去重" "11 52" "$(enumerate_open_channels '11,52,11' | tr '\n' ' ' | sed 's/ $//')"
chk "ocl: 去掉引号" "11 52" "$(enumerate_open_channels "'11,52'" | tr '\n' ' ' | sed 's/ $//')"
chk "ocl: 过滤非法字符" "11" "$(enumerate_open_channels 'abc,11' | tr '\n' ' ' | sed 's/ $//')"
chk "ocl: 逗号后接空格" "11 52" "$(enumerate_open_channels '11, 52' | tr '\n' ' ' | sed 's/ $//')"
chk "ocl: 区间混合空格" "11 12 13" "$(enumerate_open_channels '11 - 13' | tr '\n' ' ' | sed 's/ $//')"
chk "ocl: 编号首尾带空格" "11 52" "$(enumerate_open_channels ' 11 , 52 ' | tr '\n' ' ' | sed 's/ $//')"

# count_open_channels: 计算频道数
chk "coc: 普通列表数量" "2" "$(count_open_channels '11,52')"
chk "coc: 区间数量" "5" "$(count_open_channels '11-15')"
chk "coc: 含非法频道数量" "2" "$(count_open_channels '1,8,40,11')"
chk "coc: 逗号后接空格数量" "2" "$(count_open_channels '11, 52')"
chk "coc: 为空则数量为 0" "0" "$(count_open_channels '')"

# normalize_data_path: /data 软链接有效性检测
# 普通文件保持原样
nd="$WORK/nd"
mkdir -p "$nd"
printf 'real\n' >"$nd/regfile"
normalize_data_path "$nd/regfile" file
chk "nd: 普通文件保持不变" "real" "$(cat "$nd/regfile" 2>/dev/null)"
chk "nd: 普通文件不备份" 0 "$(bak_count "$nd/regfile")"

# 真实目录原样保留
mkdir -p "$nd/regdir"
normalize_data_path "$nd/regdir" directory
chk "nd: 真实目录保持不变" "yes" "$([ -d "$nd/regdir" ] && [ ! -L "$nd/regdir" ] && echo yes || echo no)"

# 空路径不处理
normalize_data_path "$nd/missing" file
chk "nd: 路径不存在则不处理" "no" "$([ -e "$nd/missing" ] && echo yes || echo no)"

# 软链接指向有效文件时发日志提醒但原样保留, 不产生备份
ndf="$WORK/ndf"
mkdir -p "$ndf"
printf 'TGT\n' >"$ndf/target"
ln -s "$ndf/target" "$ndf/link"
ndf_err=$(normalize_data_path "$ndf/link" file 2>&1 >/dev/null)
chk "ndf: 指向有效文件的软链接保持不变" "yes" "$([ -L "$ndf/link" ] && echo yes || echo no)"
chk "ndf: 指向有效文件的软链接不产生备份文件" 0 "$(bak_count "$ndf/link")"
chk "ndf: 目标文件不变" "TGT" "$(cat "$ndf/target")"
chk "ndf: 打印 WARN 日志" "yes" "$(printf '%s' "$ndf_err" | grep -q WARN && echo yes || echo no)"

# 文件类型软链接却指向目录, 备份重建
ndfm="$WORK/ndfm"
mkdir -p "$ndfm/adir"
ln -s "$ndfm/adir" "$ndfm/link"
normalize_data_path "$ndfm/link" file 2>/dev/null
chk "ndfm: 指向目录的文件软链接备份并重建" "no" "$([ -L "$ndfm/link" ] && echo yes || echo no)"
chk "ndfm: 类型不符则备份" 1 "$(bak_count "$ndfm/link")"

# 空文件软链接，备份重建
ndd="$WORK/ndd"
mkdir -p "$ndd"
ln -s /mnt/nope/x "$ndd/dead"
normalize_data_path "$ndd/dead" file 2>/dev/null
chk "ndd: 空软链接备份重建" "no" "$([ -L "$ndd/dead" ] && echo yes || echo no)"
ndd_bak=$(find "$ndd" -name 'dead.*.bak' | head -n1)
chk "ndd: 备份空软链接" "/mnt/nope/x" "$(readlink "$ndd_bak")"

# 软链接指向有效目录时发日志提醒但保留
ndr="$WORK/ndr"
mkdir -p "$ndr/realdir"
printf 'keep\n' >"$ndr/realdir/state"
ln -s "$ndr/realdir" "$ndr/dlink"
ndr_err=$(normalize_data_path "$ndr/dlink" directory 2>&1 >/dev/null)
chk "ndr: 软链接指向真实目录时保持不变" "yes" "$([ -L "$ndr/dlink" ] && echo yes || echo no)"
chk "ndr: 软链接指向真实目录时不产生备份" 0 "$(bak_count "$ndr/dlink")"
chk "ndr: 目标数据不被清空" "keep" "$(cat "$ndr/dlink/state" 2>/dev/null)"
chk "ndr: 打印 WARN 日志" "yes" "$(printf '%s' "$ndr_err" | grep -q WARN && echo yes || echo no)"

# 目录软链接却指向文件，备份重建
ndrf="$WORK/ndrf"
mkdir -p "$ndrf"
printf 'x' >"$ndrf/afile"
ln -s "$ndrf/afile" "$ndrf/dl"
normalize_data_path "$ndrf/dl" directory 2>/dev/null
chk "ndrf: 指向文件的目录软链接备份并重建" "no" "$([ -L "$ndrf/dl" ] && echo yes || echo no)"
chk "ndrf: 备份后成功创建新目录" "yes" "$(mkdir -p "$ndrf/dl" && [ -d "$ndrf/dl" ] && [ ! -L "$ndrf/dl" ] && echo yes || echo no)"

# 空目录软链接，备份重建
ndrd="$WORK/ndrd"
mkdir -p "$ndrd"
ln -s /mnt/nope/d "$ndrd/dl"
normalize_data_path "$ndrd/dl" directory 2>/dev/null
chk "ndrd: 空目录软链接备份重建" "no" "$([ -L "$ndrd/dl" ] && echo yes || echo no)"

# 软链接 WARN 日志发送到 stderr
ndw="$WORK/ndw"
mkdir -p "$ndw"
ln -s /nope "$ndw/l"
nd_err=$(normalize_data_path "$ndw/l" file 2>&1 >/dev/null)
chk "ndw: WARN 发送到 stderr" "yes" "$(printf '%s' "$nd_err" | grep -q WARN && echo yes || echo no)"

# 同一份文件一秒内多次备份, 备份名添加序号，避免只产生一份备份数据
ndc="$WORK/ndc"
mkdir -p "$ndc"
# shellcheck disable=SC2329
date() { echo 'FIXEDTS'; }
ln -s /a "$ndc/c"
normalize_data_path "$ndc/c" file 2>/dev/null
ln -s /b "$ndc/c"
normalize_data_path "$ndc/c" file 2>/dev/null
unset -f date
chk "ndc: 首个备份" "yes" "$([ -L "$ndc/c.FIXEDTS.bak" ] && echo yes || echo no)"
chk "ndc: 二次备份，结尾添加序号" "yes" "$([ -L "$ndc/c.FIXEDTS.1.bak" ] && echo yes || echo no)"
chk "ndc: 产生两份备份文件" 2 "$(bak_count "$ndc/c")"

# sync_template_file: target 是有效软链接时当作用户自定义数据, 保持原样
nds="$WORK/nds"
mkdir -p "$nds"
printf 'srcv\n' >"$nds/src"
printf 'usercustom\n' >"$nds/orig"
ln -s "$nds/orig" "$nds/t"
msg=$(sync_template_file "$nds/src" "$nds/t" "$nds/ref" 2>/dev/null)
chk "nds: 有效软链接 target 保持不变" "yes" "$([ -L "$nds/t" ] && echo yes || echo no)"
chk "nds: 不覆盖自定义数据" "yes" "$(printf '%s' "$msg" | grep -q 'keep customized' && echo yes || echo no)"
chk "nds: 软链接目标保持不变" "usercustom" "$(cat "$nds/orig")"
chk "nds: 不产生备份文件" 0 "$(bak_count "$nds/t")"

# sync_template_file: target 是无效软链接时备份重建
ndsb="$WORK/ndsb"
mkdir -p "$ndsb"
printf 'srcv\n' >"$ndsb/src"
ln -s /nonexistent/x "$ndsb/t"
sync_template_file "$ndsb/src" "$ndsb/t" "$ndsb/ref" >/dev/null 2>&1
chk "ndsb: 空 target 软链接，备份重建" "yes" "$([ -f "$ndsb/t" ] && [ ! -L "$ndsb/t" ] && echo yes || echo no)"
chk "ndsb: 重建的文件与模板相同" "srcv" "$(cat "$ndsb/t")"
chk "ndsb: 备份空软链接" 1 "$(bak_count "$ndsb/t")"

# sync_template_file: ref 是有效软链接时保持不变
ndsr="$WORK/ndsr"
mkdir -p "$ndsr"
printf 'new\n' >"$ndsr/src"
printf 'old\n' >"$ndsr/t"
printf 'REFDATA\n' >"$ndsr/refext"
ln -s "$ndsr/refext" "$ndsr/ref"
sync_template_file "$ndsr/src" "$ndsr/t" "$ndsr/ref" >/dev/null 2>&1
chk "ndsr: target 从模板更新" "new" "$(cat "$ndsr/t")"
chk "ndsr: ref 仍是软链接" "yes" "$([ -L "$ndsr/ref" ] && echo yes || echo no)"
chk "ndsr: ref 目标保持不变" "REFDATA" "$(cat "$ndsr/refext")"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
