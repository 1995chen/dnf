#!/bin/bash
# 服务端启动屏障，用来确保服务端按照依赖顺序启动

: "${DNF_BARRIER_DIR:=/data/.barrier}"
: "${DNF_BARRIER_CONF:=/home/template/init/lib/barrier.conf}"
: "${BARRIER_DEP_TIMEOUT:=600}"
: "${BARRIER_PROBE_TIMEOUT:=600}"
: "${BARRIER_POLL_INTERVAL:=0.2}"

barrier_ready_dir() { printf '%s/ready' "$DNF_BARRIER_DIR"; }
barrier_started_dir() { printf '%s/started' "$DNF_BARRIER_DIR"; }

barrier_init_dirs() {
    mkdir -p "$(barrier_ready_dir)" "$(barrier_started_dir)"
}

barrier_conf_rows() {
    [ -f "$DNF_BARRIER_CONF" ] || return 1
    local line prog deps probes
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line#"${line%%[![:space:]]*}"}"
        [ -z "$line" ] && continue
        case "$line" in \#*) continue ;; esac
        IFS='|' read -r prog deps probes <<<"$line"
        prog="$(barrier__trim "$prog")"
        deps="$(barrier__trim "$deps")"
        probes="$(barrier__trim "$probes")"
        [ -n "$prog" ] || continue
        printf '%s\x1f%s\x1f%s\n' "$prog" "$deps" "$probes"
    done <"$DNF_BARRIER_CONF"
}

barrier__trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

barrier_conf_programs() {
    barrier_conf_rows | cut -d$'\x1f' -f1
}

barrier_conf_lookup() {
    local target="$1" prog deps probes glob_hit=""
    while IFS=$'\x1f' read -r prog deps probes; do
        if [ "$prog" = "$target" ]; then
            printf '%s\t%s\n' "$deps" "$probes"
            return 0
        fi
        case "$prog" in
        *'*'*)
            # shellcheck disable=SC2254
            case "$target" in
            $prog)
                [ -z "$glob_hit" ] && glob_hit="$deps"$'\t'"$probes"
                ;;
            esac
            ;;
        esac
    done < <(barrier_conf_rows)
    if [ -n "$glob_hit" ]; then
        printf '%s\n' "$glob_hit"
        return 0
    fi
    return 1
}

barrier_probe_one() {
    local probe="$1" program="$2"
    local type="${probe%%:*}" arg="${probe#*:}"
    case "$type" in
    file)
        local f files=() saved_ifs="$IFS"
        IFS=
        # shellcheck disable=SC2206
        files=($arg)
        IFS="$saved_ifs"
        for f in "${files[@]}"; do
            [ -e "$f" ] || continue
            [ -s "$f" ] && return 0
        done
        return 1
        ;;
    tcp)
        socat -T2 /dev/null "TCP:${arg}" >/dev/null 2>&1
        ;;
    udp)
        socat -T1 /dev/null "UDP-SENDTO:${arg}" >/dev/null 2>&1
        ;;
    logmark)
        local file="${arg%%:*}" regex="${arg#*:}"
        [ -f "$file" ] && grep -Eq -- "$regex" "$file"
        ;;
    cmd)
        PROGRAM="$program" bash -c "$arg" >/dev/null 2>&1
        ;;
    *)
        echo "[barrier] unknown probe type: $type" >&2
        return 1
        ;;
    esac
}

barrier_probe_all() {
    local program="$1" probes="$2"
    if [ -z "$probes" ]; then
        return 0
    fi
    local p parts=()
    IFS=';' read -ra parts <<<"$probes"
    for p in "${parts[@]}"; do
        p="$(barrier__trim "$p")"
        [ -z "$p" ] && continue
        barrier_probe_one "$p" "$program" || return 1
    done
    return 0
}

barrier_is_ready() { [ -e "$(barrier_ready_dir)/$1" ]; }

barrier_publish() {
    local prog="$1" dir tmp
    dir="$(barrier_ready_dir)"
    tmp="$(mktemp "$dir/.tmp.$prog.XXXXXX" 2>/dev/null)" || return 1
    printf '%s %s\n' "$(date +%s)" "$$" >"$tmp" 2>/dev/null || {
        rm -f "$tmp"
        return 1
    }
    mv -f "$tmp" "$dir/$prog"
}

barrier_revoke() { rm -f "$(barrier_ready_dir)/$1" 2>/dev/null; return 0; }

barrier_wait_deps() {
    local prog="$1" deps="$2" timeout="$3"
    if [ -z "$deps" ]; then
        return 0
    fi
    local start=$SECONDS elapsed last_log=0 missing dep
    local deplist=()
    IFS=',' read -ra deplist <<<"$deps"
    while :; do
        missing=""
        for dep in "${deplist[@]}"; do
            dep="$(barrier__trim "$dep")"
            [ -z "$dep" ] && continue
            barrier_is_ready "$dep" || missing="$missing $dep"
        done
        [ -z "$missing" ] && return 0
        elapsed=$((SECONDS - start))
        [ "$elapsed" -ge "$timeout" ] && {
            echo "[barrier] $prog timed out waiting for deps:$missing" >&2
            return 1
        }
        if [ $((elapsed - last_log)) -ge 10 ]; then
            echo "[barrier] $prog waiting for deps:$missing (${elapsed}s)" >&2
            last_log=$elapsed
        fi
        sleep "$BARRIER_POLL_INTERVAL"
    done
}

barrier_prober_loop() {
    local prog="$1" probes="$2" timeout="$3" gen="${4:-}"
    local start=$SECONDS elapsed
    while :; do
        if barrier_probe_all "$prog" "$probes"; then
            if [ -n "$gen" ] &&
                [ "$(cat "$(barrier_started_dir)/$prog" 2>/dev/null)" != "$gen" ]; then
                echo "[barrier] $prog superseded by a newer start, prober exiting" >&2
                return 1
            fi
            barrier_publish "$prog"
            echo "[barrier] $prog ready" >&2
            return 0
        fi
        elapsed=$((SECONDS - start))
        [ "$elapsed" -ge "$timeout" ] && {
            echo "[barrier] $prog readiness probe timed out (${elapsed}s)" >&2
            return 1
        }
        sleep "$BARRIER_POLL_INTERVAL"
    done
}

barrier_main() {
    local prog="$1"
    shift
    barrier_init_dirs
    barrier_revoke "$prog"
    rm -f "$(barrier_ready_dir)/.tmp.$prog."* 2>/dev/null

    local gen now
    now="$(date +%s 2>/dev/null)"
    gen="${now}.$$.${RANDOM:-0}"
    printf '%s' "$gen" >"$(barrier_started_dir)/$prog" 2>/dev/null || true

    local row deps probes
    if row="$(barrier_conf_lookup "$prog")"; then
        deps="${row%%$'\t'*}"
        probes="${row#*$'\t'}"
    else
        echo "[barrier] WARN no conf row for $prog, starting unguarded" >&2
        deps=""
        probes=""
    fi

    if ! barrier_wait_deps "$prog" "$deps" "$BARRIER_DEP_TIMEOUT"; then
        echo "[barrier] $prog dependency timeout, exiting for supervisor retry" >&2
        exit 1
    fi

    local child=""
    trap '[ -n "$child" ] && kill -TERM "$child" 2>/dev/null' INT TERM

    "$@" &
    child=$!

    if [ -n "$probes" ]; then
        barrier_prober_loop "$prog" "$probes" "$BARRIER_PROBE_TIMEOUT" "$gen" &
    else
        barrier_publish "$prog"
        echo "[barrier] $prog ready, no probe" >&2
    fi

    wait "$child"
    exit $?
}
