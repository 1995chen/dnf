#!/bin/bash

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
CONF_D="${SCRIPT_PATH}/../../../../etc/supervisor/conf.d"
export DNF_BARRIER_CONF="${SCRIPT_PATH}/barrier.conf"

# shellcheck source=barrier.sh
source "${SCRIPT_PATH}/barrier.sh"

failed=0
pass=0
fail() {
    printf "FAIL %s\n" "$1"
    failed=$((failed + 1))
}
okmsg() { pass=$((pass + 1)); }

mapfile -t programs < <(
    grep -hoE '^\[program:[^]]+\]' \
        "${CONF_D}"/dnf.conf \
        "${CONF_D}"/gate.conf \
        "${CONF_D}"/netbird.conf \
        "${CONF_D}"/tailscale.conf \
        "${CONF_D}"/channel.conf.template 2>/dev/null |
        sed -E 's/^\[program:(.*)\]$/\1/' | sort -u
)

init_sh="${SCRIPT_PATH}/../init.sh"
entrypoint="${SCRIPT_PATH}/../../../../docker-entrypoint.sh"
if ! grep -qF 'program:game_${SERVER_GROUP_NAME}${num}' "$init_sh"; then
    fail "init.sh game program name template changed, update this test"
fi
while IFS= read -r gname; do
    [ -n "$gname" ] || continue
    programs+=("game_${gname}01")
done < <(grep -oE 'SERVER_GROUP_NAME_[0-9]+="[^"]+"' "$entrypoint" |
    sed -E 's/.*="([^"]+)"/\1/')

echo "== every supervisor program has a conf row =="
for prog in "${programs[@]}"; do
    if barrier_conf_lookup "$prog" >/dev/null; then okmsg; else
        fail "no barrier.conf row for program '$prog'"
    fi
done

echo "== conf dependencies reference known programs =="
mapfile -t conf_progs < <(barrier_conf_programs)
is_conf_prog() {
    local d="$1" p
    for p in "${conf_progs[@]}"; do [ "$p" = "$d" ] && return 0; done
    return 1
}
while IFS=$'\x1f' read -r prog deps _probes; do
    [ -n "$deps" ] || continue
    IFS=',' read -ra dl <<<"$deps"
    for d in "${dl[@]}"; do
        if is_conf_prog "$d"; then okmsg; else
            fail "program '$prog' depends on '$d' which has no conf row"
        fi
    done
done < <(barrier_conf_rows)

echo "== dependency graph is acyclic =="
declare -A indeg=() adj=()
nodes=()
while IFS=$'\x1f' read -r prog deps _probes; do
    nodes+=("$prog")
    [ -n "${indeg[$prog]+x}" ] || indeg[$prog]=0
    [ -n "$deps" ] || continue
    IFS=',' read -ra dl <<<"$deps"
    for d in "${dl[@]}"; do
        adj[$d]="${adj[$d]:-} $prog"
        indeg[$prog]=$((${indeg[$prog]:-0} + 1))
    done
done < <(barrier_conf_rows)

queue=()
for n in "${nodes[@]}"; do [ "${indeg[$n]:-0}" -eq 0 ] && queue+=("$n"); done
removed=0
while [ "${#queue[@]}" -gt 0 ]; do
    cur="${queue[0]}"
    queue=("${queue[@]:1}")
    removed=$((removed + 1))
    for nxt in ${adj[$cur]:-}; do
        indeg[$nxt]=$((indeg[$nxt] - 1))
        [ "${indeg[$nxt]}" -eq 0 ] && queue+=("$nxt")
    done
done
if [ "$removed" -eq "${#nodes[@]}" ]; then okmsg; else
    fail "dependency graph has a cycle (removed=$removed of ${#nodes[@]})"
fi

echo "== 每个 [program] 都设置了 stopasgroup/killasgroup =="
check_group_kill() {
    local ctx="$1" conf="$2"
    local -a hdr
    IFS=$'\n' read -d '' -ra hdr \
        <<<"$(grep -nE '^[[:space:]]*\[' <<<"$conf" | awk -F: '{print $1}')"
    # 不用 ${hdr[-1]}：负数下标 bash 4.3 才支持，centos7 是 4.2
    local last=$((${#hdr[@]} - 1))
    [ "${hdr[last]}" = "" ] && unset 'hdr[last]'
    [ "${#hdr[@]}" -eq 0 ] && return 0
    local i start end section head name miss
    for ((i = 0; i < ${#hdr[@]}; i++)); do
        start="${hdr[i]}"
        if [ "$((i + 1))" -lt "${#hdr[@]}" ]; then
            end="$((hdr[i + 1] - 1))"
        else
            end='$'
        fi
        section="$(sed -n "${start},${end}p" <<<"$conf")"
        head="${section%%$'\n'*}"
        case "$head" in *"[program:"*) ;; *) continue ;; esac
        name="${head#*\[program:}"
        name="${name%%\]*}"
        miss=0
        grep -qE '^[[:space:]]*stopasgroup[[:space:]]*=[[:space:]]*true[[:space:]]*$' <<<"$section" ||
            { fail "program '$name' ($ctx) missing stopasgroup=true"; miss=1; }
        grep -qE '^[[:space:]]*killasgroup[[:space:]]*=[[:space:]]*true[[:space:]]*$' <<<"$section" ||
            { fail "program '$name' ($ctx) missing killasgroup=true"; miss=1; }
        [ "$miss" -eq 0 ] && okmsg
    done
}
for f in dnf.conf channel.conf.template gate.conf netbird.conf tailscale.conf; do
    check_group_kill "$f" "$(cat "${CONF_D}/$f")"
done

INIT_SH="${SCRIPT_PATH}/../init.sh"
check_group_kill "init.sh game block" \
    "$(awk '/\[program:game_/{f=1} f{print} f&&/^EOF$/{exit}' "$INIT_SH")"

echo "== no cmd: probe contains ';' =="
while IFS=$'\x1f' read -r prog _deps probes; do
    case "$probes" in
    *"cmd:"*)
        # 首个 cmd: 之后的内容不能带 ;
        rest="cmd:${probes#*cmd:}"
        case "$rest" in
        *";"*) fail "program '$prog' has a cmd: probe containing ';'" ;;
        *) okmsg ;;
        esac
        ;;
    esac
done < <(barrier_conf_rows)

echo "== cmd: helper scripts are shipped and executable =="
while IFS=$'\x1f' read -r prog _deps probes; do
    case "$probes" in
    *"cmd:"*) ;;
    *) continue ;;
    esac
    rest="${probes#*cmd:}"
    cmdtok="${rest%%[[:space:]]*}"
    case "$cmdtok" in
    /home/template/*)
        repo="${SCRIPT_PATH}/../../${cmdtok#/home/template/}"
        if [ -f "$repo" ] && [ -x "$repo" ]; then okmsg; else
            fail "program '$prog' cmd: script missing or not executable: $cmdtok"
        fi
        ;;
    esac
done < <(barrier_conf_rows)

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
