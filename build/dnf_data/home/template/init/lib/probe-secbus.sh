#!/bin/bash
# secagent就绪探针

want="${SECAGENT_CHANNEL_NUM:-12}"
glob="${SECBUS_GLOB:-/dev/shm/sec_tss_sdk_bus_*}"
glob_alt="${SECBUS_GLOB_ALT-/dev/shm/sec/tss_sdk_bus_*}"

case "$want" in
'' | *[!0-9]*)
    echo "probe-secbus: SECAGENT_CHANNEL_NUM='$want' is not numeric" >&2
    exit 1
    ;;
esac
if [ "$want" -lt 1 ]; then
    echo "probe-secbus: SECAGENT_CHANNEL_NUM=$want is invalid" >&2
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
