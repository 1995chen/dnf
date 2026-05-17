#!/bin/bash
# barrier.sh 测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

export DNF_BARRIER_DIR="$WORK/barrier"
export DNF_BARRIER_CONF="$WORK/test.conf"
export BARRIER_POLL_INTERVAL=1

cat >"$DNF_BARRIER_CONF" <<'CONF'
# test conf
a | | cmd:true
b | a | file:WORK/b.pid
zergsvr_secagent | zergsvr | file:WORK/secagent.pid;file:WORK/shm/sec_tss_sdk_bus_*
game_* | bridge,zergsvr_secagent | cmd:test -s WORK/game/${PROGRAM#game_}.pid
CONF
sed -i "s#WORK#${WORK}#g" "$DNF_BARRIER_CONF"

# shellcheck source=barrier.sh
source "${SCRIPT_PATH}/barrier.sh"

failed=0
pass=0
check() {
    local desc="$1" got="$2" want="$3"
    if [ "$got" = "$want" ]; then
        pass=$((pass + 1))
    else
        printf "FAIL %-50s got=%q want=%q\n" "$desc" "$got" "$want"
        failed=$((failed + 1))
    fi
}
ok() {
    local desc="$1"
    shift
    if "$@"; then pass=$((pass + 1)); else
        printf "FAIL %-50s (expected success)\n" "$desc"
        failed=$((failed + 1))
    fi
}
no() {
    local desc="$1"
    shift
    if "$@"; then
        printf "FAIL %-50s (expected failure)\n" "$desc"
        failed=$((failed + 1))
    else pass=$((pass + 1)); fi
}

count_glob() {
    local n=0 f
    for f in "$@"; do
        [ -e "$f" ] && n=$((n + 1))
    done
    printf '%s' "$n"
}

echo "== conf lookup =="
check "literal deps" "$(barrier_conf_lookup zergsvr_secagent | cut -f1)" "zergsvr"
contains_probe=$(barrier_conf_lookup zergsvr_secagent | cut -f2)
case "$contains_probe" in *"file:${WORK}/shm/sec_tss_sdk_bus_*"*) pass=$((pass + 1)) ;; *)
    printf "FAIL literal probes got=%q\n" "$contains_probe"
    failed=$((failed + 1))
    ;;
esac
check "glob deps for game_cain01" "$(barrier_conf_lookup game_cain01 | cut -f1)" "bridge,zergsvr_secagent"
check "empty deps row keeps empty deps" "$(barrier_conf_lookup a | cut -f1)" ""
check "empty deps row keeps probes" "$(barrier_conf_lookup a | cut -f2)" "cmd:true"
no "unknown program lookup fails" barrier_conf_lookup nosuchprog

echo "== file probe =="
no "missing file fails" barrier_probe_one "file:$WORK/b.pid" b
: >"$WORK/b.pid"
no "empty file fails" barrier_probe_one "file:$WORK/b.pid" b
echo 123 >"$WORK/b.pid"
ok "non-empty file passes" barrier_probe_one "file:$WORK/b.pid" b

echo "== file glob =="
mkdir -p "$WORK/shm"
no "no glob match fails" barrier_probe_one "file:$WORK/shm/sec_tss_sdk_bus_*" zergsvr_secagent
for i in 1 2 3; do echo 1 >"$WORK/shm/sec_tss_sdk_bus_$i"; done
ok "any non-empty glob match passes" barrier_probe_one "file:$WORK/shm/sec_tss_sdk_bus_*" zergsvr_secagent
: >"$WORK/shm/sec_tss_sdk_bus_2"
ok "still passes while a sibling match is non-empty" barrier_probe_one "file:$WORK/shm/sec_tss_sdk_bus_*" zergsvr_secagent

echo "== cmd / logmark / probe_all =="
ok "cmd:true passes" barrier_probe_one "cmd:true" a
no "cmd:false fails" barrier_probe_one "cmd:false" a
# shellcheck disable=SC2016
ok "cmd sees PROGRAM env" barrier_probe_one 'cmd:test "$PROGRAM" = game_x' game_x
echo "server started ok" >"$WORK/m.log"
ok "logmark match" barrier_probe_one "logmark:$WORK/m.log:started ok" a
no "logmark no match" barrier_probe_one "logmark:$WORK/m.log:NOPE" a
no "unknown probe type fails closed" barrier_probe_one "bogus:whatever" a
ok "probe_all all pass" barrier_probe_all a "cmd:true;cmd:true"
no "probe_all one fail" barrier_probe_all a "cmd:true;cmd:false"

mkdir -p "$WORK/sh2"
echo 7 >"$WORK/x.pid"
for i in 1 2 3; do echo 1 >"$WORK/sh2/sec_tss_sdk_bus_$i"; done
ok "probe_all multi-probe w/ glob arg intact" \
    barrier_probe_all zz "file:$WORK/x.pid;file:$WORK/sh2/sec_tss_sdk_bus_*"

echo "== marker publish / revoke / atomicity =="
barrier_init_dirs
no "not ready before publish" barrier_is_ready a
barrier_publish a
ok "ready after publish" barrier_is_ready a
check "no tmp leftover" "$(count_glob "$DNF_BARRIER_DIR"/ready/.tmp*)" "0"
barrier_revoke a
no "not ready after revoke" barrier_is_ready a
for _ in $(seq 1 20); do barrier_publish a & done
wait
check "concurrent publish -> single marker" "$(count_glob "$DNF_BARRIER_DIR"/ready/a)" "1"
check "concurrent publish -> no tmp leak" "$(count_glob "$DNF_BARRIER_DIR"/ready/.tmp*)" "0"
barrier_revoke a

echo "== wait_deps =="
ok "empty deps returns immediately" barrier_wait_deps a "" 1
no "missing dep times out" barrier_wait_deps b "a" 1
barrier_publish a
ok "present dep passes" barrier_wait_deps b "a" 2
barrier_revoke a

echo "== prober_loop =="
rm -f "$WORK/p.pid"
no "prober times out, no publish" barrier_prober_loop pp "file:$WORK/p.pid" 1
no "no marker after prober timeout" barrier_is_ready pp
echo 1 >"$WORK/p.pid"
ok "prober passes and publishes" barrier_prober_loop pp "file:$WORK/p.pid" 2
ok "marker present after prober" barrier_is_ready pp

echo "== prober generation guard (no stale republish after restart) =="
mkdir -p "$DNF_BARRIER_DIR/started"
echo 1 >"$WORK/g.pid"
echo "GEN_NEW" >"$DNF_BARRIER_DIR/started/gg"
no "stale-generation prober does not publish" \
    barrier_prober_loop gg "file:$WORK/g.pid" 1 GEN_OLD
no "no marker when generation stale" barrier_is_ready gg
echo "GEN_CUR" >"$DNF_BARRIER_DIR/started/gg"
ok "matching-generation prober publishes" \
    barrier_prober_loop gg "file:$WORK/g.pid" 2 GEN_CUR
ok "marker present with matching generation" barrier_is_ready gg
barrier_revoke gg
ok "no-gen arg keeps legacy behavior (publishes)" \
    barrier_prober_loop gg "file:$WORK/g.pid" 2
barrier_revoke gg

echo "== barrier-wait latch survives wrapper exit (daemonizing service) =="

printf 'daemonish | | file:%s/d.pid\n' "$WORK" >>"$DNF_BARRIER_CONF"
echo 1 >"$WORK/d.pid"
BARRIER_DEP_TIMEOUT=2 BARRIER_PROBE_TIMEOUT=3 BARRIER_POLL_INTERVAL=1 \
    bash "${SCRIPT_PATH}/barrier-wait" daemonish bash -c 'exit 0' >/dev/null 2>&1
sleep 2
ok "marker persists after daemonizing wrapper exits" barrier_is_ready daemonish
barrier_revoke daemonish

echo "== barrier-wait publishes immediately for an empty-probe row =="
printf 'noprobe | | \n' >>"$DNF_BARRIER_CONF"
BARRIER_DEP_TIMEOUT=2 BARRIER_PROBE_TIMEOUT=3 BARRIER_POLL_INTERVAL=1 \
    bash "${SCRIPT_PATH}/barrier-wait" noprobe bash -c 'exit 0' >/dev/null 2>&1
sleep 1
ok "empty-probe row publishes its marker" barrier_is_ready noprobe
barrier_revoke noprobe

echo "== empty-probe row still waits for its deps before publishing =="
printf 'gated | gatedep | \n' >>"$DNF_BARRIER_CONF"
barrier_revoke gatedep
( sleep 2; barrier_publish gatedep ) &
BARRIER_DEP_TIMEOUT=6 BARRIER_PROBE_TIMEOUT=3 BARRIER_POLL_INTERVAL=1 \
    bash "${SCRIPT_PATH}/barrier-wait" gated bash -c 'exit 0' >/dev/null 2>&1
ok "empty-probe row published after its dep became ready" barrier_is_ready gated
wait
barrier_revoke gated
barrier_revoke gatedep

echo "== extreme: Chinese / spaces / special symbols in paths and content =="
ex="$WORK/ex"
sp_dir="$ex/dir with spaces"
zh_dir="$ex/中文目录"
mix_dir="$ex/混合 目录 a&b"
mkdir -p "$sp_dir" "$zh_dir" "$mix_dir"

# file 探针：空格、中文、特殊字符路径
echo x >"$sp_dir/p.pid"
ok "file path with spaces" barrier_probe_one "file:$sp_dir/p.pid" prog
echo 1 >"$zh_dir/进程.pid"
ok "file path+name Chinese" barrier_probe_one "file:$zh_dir/进程.pid" prog
echo 1 >"$mix_dir/svr.pid"
ok "file spaces+Chinese+&" barrier_probe_one "file:$mix_dir/svr.pid" prog
echo 1 >"$sp_dir/server_01.pid"
ok "file glob in spaced dir" barrier_probe_one "file:$sp_dir/server_*.pid" prog
no "file glob no match spaced dir" barrier_probe_one "file:$sp_dir/none_*.pid" prog
scname='weird @#%+=,.~^!.pid'
echo 1 >"$sp_dir/$scname"
ok "file special-char filename" barrier_probe_one "file:$sp_dir/$scname" prog
: >"$sp_dir/empty.pid"
no "file empty file fails" barrier_probe_one "file:$sp_dir/empty.pid" prog

# file glob：中文目录、空格文件名
for i in 1 2 3; do echo 1 >"$zh_dir/总线_$i"; done
ok "file glob Chinese dir+name" barrier_probe_one "file:$zh_dir/总线_*" prog
no "file glob no match Chinese dir" barrier_probe_one "file:$zh_dir/不存在_*" prog
echo 1 >"$mix_dir/bus 1"
echo 1 >"$mix_dir/bus 2"
ok "file glob spaced filename" barrier_probe_one "file:$mix_dir/bus *" prog

# logmark：空格+中文路径、中文正则、特殊符号正则
lf="$mix_dir/run log.txt"
printf '启动完成 service started ok v1.2\n' >"$lf"
ok "logmark Chinese literal" barrier_probe_one "logmark:$lf:启动完成" prog
ok "logmark regex with space" barrier_probe_one "logmark:$lf:service started" prog
ok "logmark regex metachar" barrier_probe_one "logmark:$lf:v[0-9]\\.[0-9]" prog
no "logmark no match" barrier_probe_one "logmark:$lf:不存在XYZ" prog

# cmd：中文、空格、引号、冒号、管道符、特殊符号
ok "cmd chinese noop" barrier_probe_one 'cmd:echo 中文内容 >/dev/null' prog
ok "cmd spaces+quotes" barrier_probe_one 'cmd:[ "a b" = "a b" ]' prog
ok "cmd colon in arg" barrier_probe_one 'cmd:test "x:y" = "x:y"' prog
ok "cmd pipe no semicolon" barrier_probe_one 'cmd:echo hi | grep -q hi' prog
# shellcheck disable=SC2016
ok "cmd sees special PROGRAM" barrier_probe_one 'cmd:[ "$PROGRAM" = "游戏 a&b" ]' "游戏 a&b"
no "cmd false" barrier_probe_one 'cmd:false' prog

# probe_all：含管道符与空格但不含 ; 的 cmd，中文文件名
ok "probe_all cmd pipe+spaces" barrier_probe_all prog 'cmd:echo a b c | grep -q b'
ok "probe_all multi chinese+cmd" barrier_probe_all prog "file:$zh_dir/进程.pid;cmd:true"
ok "probe_all empty -> ready" barrier_probe_all prog ""

# 特殊规则
save_conf="$DNF_BARRIER_CONF"
sp_conf="$ex/extreme.conf"
cat >"$sp_conf" <<'EOF'
  # leading-space comment
   spaced_prog   |  dep1 , dep2  |  cmd:echo hi | grep -q hi
zh_程序 | dep中文 | logmark:/var/中文 日志.log:启动完成
game_* | bridge | cmd:test -s "/p/${PROGRAM#game_}.pid"
EOF
DNF_BARRIER_CONF="$sp_conf"
check "conf trims outer, keeps inner deps" "$(barrier_conf_lookup spaced_prog | cut -f1)" "dep1 , dep2"
check "conf probes keep inner pipe" "$(barrier_conf_lookup spaced_prog | cut -f2)" "cmd:echo hi | grep -q hi"
check "conf Chinese prog deps" "$(barrier_conf_lookup zh_程序 | cut -f1)" "dep中文"
check "conf Chinese prog probe" "$(barrier_conf_lookup zh_程序 | cut -f2)" "logmark:/var/中文 日志.log:启动完成"
check "conf glob still resolves" "$(barrier_conf_lookup game_siroco11 | cut -f1)" "bridge"
DNF_BARRIER_CONF="$save_conf"

echo "== 分隔符测试：tab / 空格 / 混用 / CRLF / \x1f 空字段处理 =="
sep=$'\x1f'
ws_conf="$ex/ws.conf"
{
    printf 'tabsep\t|\tdep1\t|\tcmd:true\n'
    printf 'mixsep \t| \t dep_a , dep_b \t |\t cmd:true \n'
    printf 'emptydeps\t|\t|\tcmd:true\n'
    printf 'noboth\t|\t|\n'
    printf 'crlf_prog | | cmd:true\r\n'
} >"$ws_conf"
DNF_BARRIER_CONF="$ws_conf"
check "tab-sep deps trimmed" "$(barrier_conf_lookup tabsep | cut -f1)" "dep1"
check "tab-sep probe trimmed" "$(barrier_conf_lookup tabsep | cut -f2)" "cmd:true"
check "mixed tab+space deps parsed" "$(barrier_conf_lookup mixsep | cut -f1)" "dep_a , dep_b"
check "mixed tab+space probe parsed" "$(barrier_conf_lookup mixsep | cut -f2)" "cmd:true"
check "crlf row drops trailing CR" "$(barrier_conf_lookup crlf_prog | cut -f2)" "cmd:true"

raw=$(barrier_conf_rows | grep -a '^emptydeps')
check "raw \x1f keeps 3 fields" "$(printf '%s' "$raw" | awk -F"$sep" '{print NF}')" "3"
check "raw \x1f empty deps no fold" "$(printf '%s' "$raw" | cut -d"$sep" -f2)" ""
check "raw \x1f probes intact" "$(printf '%s' "$raw" | cut -d"$sep" -f3)" "cmd:true"
raw2=$(barrier_conf_rows | grep -a '^noboth')
check "raw \x1f both empty no fold" "$(printf '%s' "$raw2" | awk -F"$sep" '{print NF}')" "3"
check "noboth empty deps" "$(barrier_conf_lookup noboth | cut -f1)" ""
check "noboth empty probes" "$(barrier_conf_lookup noboth | cut -f2)" ""

# deps 对 tab/空格或混用情况的兼容性
barrier_publish d_a
barrier_publish d_b
ok "mixed-ws csv deps satisfied" barrier_wait_deps p $' d_a \t,\t d_b \t' 1
barrier_revoke d_a
barrier_revoke d_b
no "mixed-ws csv deps missing times out" barrier_wait_deps p $' d_a \t, d_b ' 1

# probes 对 tab/空格或混用情况的兼容性
echo 1 >"$WORK/wsp.pid"
ws_probes=$' file:'"$WORK"$'/wsp.pid \t;\tcmd:true '
ok "mixed-ws probe list all pass" barrier_probe_all p "$ws_probes"
no "mixed-ws probe list one fail" barrier_probe_all p $' cmd:true ;\tcmd:false '
DNF_BARRIER_CONF="$save_conf"

# 标记文件清理，barrier 路径含空格+中文
save_dir="$DNF_BARRIER_DIR"
DNF_BARRIER_DIR="$ex/屏 障 root 中文"
barrier_init_dirs
no "weird dir: not ready pre-publish" barrier_is_ready 服务
barrier_publish 服务
ok "weird dir: ready after publish" barrier_is_ready 服务
check "weird dir: single marker" "$(count_glob "$DNF_BARRIER_DIR"/ready/服务)" "1"
check "weird dir: no tmp leak" "$(count_glob "$DNF_BARRIER_DIR"/ready/.tmp*)" "0"
barrier_revoke 服务
no "weird dir: revoked" barrier_is_ready 服务
DNF_BARRIER_DIR="$save_dir"

# 配置文件路径含空格+中文
save_conf="$DNF_BARRIER_CONF"
weird_conf="$zh_dir/屏障 配置.conf"
printf 'svc_x | | cmd:true\n' >"$weird_conf"
DNF_BARRIER_CONF="$weird_conf"
check "conf file path spaces+Chinese" "$(barrier_conf_lookup svc_x | cut -f2)" "cmd:true"
DNF_BARRIER_CONF="$save_conf"

# deps trim
ok "blank-only deps -> wait ok" barrier_wait_deps p "   " 1
barrier_publish 依赖中文
ok "Chinese dep name satisfied" barrier_wait_deps p "依赖中文" 1
barrier_revoke 依赖中文
no "missing Chinese dep times out" barrier_wait_deps p "依赖中文" 1
check "trim keeps inner Chinese+space" "$(barrier__trim '  中文 内容  ')" "中文 内容"
check "trim all-space -> empty" "$(barrier__trim '    ')" ""

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
