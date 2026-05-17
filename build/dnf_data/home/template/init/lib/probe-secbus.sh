#!/bin/bash
# secagent就绪探针

cfg="${SECAGENT_CONFIG:-/home/neople/secsvr/zergsvr/cfg/secagent_config.xml}"
glob="${SECBUS_GLOB:-/dev/shm/sec_tss_sdk_bus_*}"
glob_alt="${SECBUS_GLOB_ALT-/dev/shm/sec/tss_sdk_bus_*}"

if [ ! -r "$cfg" ]; then
    echo "probe-secbus: cannot read $cfg" >&2
    exit 1
fi

want=$(sed -n \
    's:.*<gamesvr_channel_num_>[[:space:]]*\([0-9][0-9]*\)[[:space:]]*</gamesvr_channel_num_>.*:\1:p' \
    "$cfg" | head -n1)

case "$want" in
'' | *[!0-9]*)
    echo "probe-secbus: gamesvr_channel_num_ not found/numeric in $cfg" >&2
    exit 1
    ;;
esac
if [ "$want" -lt 1 ]; then
    echo "probe-secbus: gamesvr_channel_num_=$want is invalid" >&2
    exit 1
fi

n=0
f=""
g=""
for g in "$glob" "$glob_alt"; do
    [ -n "$g" ] || continue
    files=()
    saved_ifs="$IFS"
    IFS=
    # shellcheck disable=SC2206
    files=($g)
    IFS="$saved_ifs"
    for f in "${files[@]}"; do
        [ -s "$f" ] && n=$((n + 1))
    done
done

[ "$n" -ge "$want" ]
