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

# 用法: mkzerg <文件> <self_type> <self_id>
mkzerg() {
    printf '<zerg_config>\n\t<self_cfg>\n\t\t<self_svr_info>\n\t\t\t<svr_type>%s</svr_type>\n\t\t\t<svr_id>%s</svr_id>\n\t\t\t<use_encrypt>0x0</use_encrypt>\n\t\t</self_svr_info>\n\t</self_cfg>\n</zerg_config>\n' "$2" "$3" >"$1"
}
# 用法: mksvcid <文件> <type> <id> <port> [<type> <id> <port> ...]
mksvcid() {
    local out="$1"
    shift
    printf '<svcid_config>\n' >"$out"
    while [ "$#" -ge 3 ]; do
        printf '\t<service_info_>\n\t\t<svr_type_> %s </svr_type_>\n\t\t<svr_id_> %s </svr_id_>\n\t\t<svr_ip_> 127.0.0.1 </svr_ip_>\n\t\t<svr_port_> %s </svr_port_>\n\t</service_info_>\n' "$1" "$2" "$3" >>"$out"
        shift 3
    done
    printf '</svcid_config>\n' >>"$out"
}

echo "== zerg_parse_self 解析 self 的 type 与 id =="
mkzerg "$WORK/zerg.xml" 30 570011
chk "self type+id" "30 570011" "$(zerg_parse_self "$WORK/zerg.xml")"

echo "== xml 标签带属性时不受影响 =="
{
    printf '<zerg_config>\n\t<self_cfg>\n\t\t<self_svr_info>\n'
    printf '\t\t\t<svr_type foo="1">30</svr_type>\n'
    printf '\t\t\t<svr_id bar="2">570011</svr_id>\n'
    printf '\t\t</self_svr_info>\n\t</self_cfg>\n</zerg_config>\n'
} >"$WORK/zatt.xml"
chk "跳过属性值" "30 570011" "$(zerg_parse_self "$WORK/zatt.xml")"

echo "== svcid_lookup_port 根据 type 与 id 取端口 =="
mksvcid "$WORK/svcid.xml" 31 570001 9000 2 1 9001 30 570011 9100
chk "(30,570011) 端口" "9100" "$(svcid_lookup_port "$WORK/svcid.xml" 30 570011)"
chk "(31,570001) 端口" "9000" "$(svcid_lookup_port "$WORK/svcid.xml" 31 570001)"

echo "== 同类型但不同 id 的数据不被错误匹配 =="
mksvcid "$WORK/wrongid.xml" 30 999999 8000 30 570011 9100
chk "根据 id 区分" "9100" "$(svcid_lookup_port "$WORK/wrongid.xml" 30 570011)"
chk "未匹配则返回空" "" "$(svcid_lookup_port "$WORK/wrongid.xml" 30 123456)"

echo "== 遇到缺 svr_id_ 的块不会用上一次的残留的 id =="
{
    printf '<svcid_config>\n'
    printf '\t<service_info_>\n\t\t<svr_type_> 30 </svr_type_>\n\t\t<svr_id_> 570011 </svr_id_>\n\t\t<svr_port_> 9100 </svr_port_>\n\t</service_info_>\n'
    printf '\t<service_info_>\n\t\t<svr_type_> 30 </svr_type_>\n\t\t<svr_port_> 8000 </svr_port_>\n\t</service_info_>\n'
    printf '</svcid_config>\n'
} >"$WORK/leak.xml"
chk "残留的 id 不会被使用" "9100" "$(svcid_lookup_port "$WORK/leak.xml" 30 570011)"

echo "== svcid_rewrite_port 仅更新匹配部分, 不影响同端口其它部分 =="
# 两个条目同为 9000: (31,570001) 与 (30,570011); 只改 self 那个
mksvcid "$WORK/rw.xml" 31 570001 9000 2 1 9001 30 570011 9000
svcid_rewrite_port "$WORK/rw.xml" 30 570011 9999
chk "更新 self 端口" "9999" "$(svcid_lookup_port "$WORK/rw.xml" 30 570011)"
chk "同端口的 (31,570001) 不受影响" "9000" "$(svcid_lookup_port "$WORK/rw.xml" 31 570001)"
chk "其他数据 (2,1) 不受影响" "9001" "$(svcid_lookup_port "$WORK/rw.xml" 2 1)"
chk "更新后结构不变" "3" "$(grep -c '<service_info_>' "$WORK/rw.xml")"

echo "== 匹配失败时不改变文件内容 =="
mksvcid "$WORK/nomatch.xml" 30 570011 9100
before=$(cat "$WORK/nomatch.xml")
svcid_rewrite_port "$WORK/nomatch.xml" 99 88 7777
chk "无任何匹配则跳过" "$before" "$(cat "$WORK/nomatch.xml")"

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
