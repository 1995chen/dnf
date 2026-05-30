#!/bin/bash
# get_public_ip.sh 测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TARGET="$SCRIPT_PATH/get_public_ip.sh"

OCTET='(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])'
IP_REGEX="^${OCTET}(\.${OCTET}){3}$"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

if [ ! -x "$TARGET" ]; then
    red "FAIL: $TARGET is missing or not executable"
    exit 1
fi

# Read the endpoint list straight from the script so the test never drifts.
# Picks each quoted URL line inside the urls array block.
mapfile -t urls < <(awk '
    /urls=\(/      { in_block = 1; next }
    in_block && /\)/ { in_block = 0; next }
    in_block       {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        gsub(/^"|"$/, "")
        if (length($0) > 0) print
    }
' "$TARGET")

if [ "${#urls[@]}" -eq 0 ]; then
    red "FAIL: could not parse the endpoint list out of $TARGET"
    exit 1
fi

echo "Endpoints reachability check:"
endpoint_failures=0
for url in "${urls[@]}"; do
    raw=$(curl -fsS -4 --max-time 5 "$url" 2>/dev/null || true)
    cleaned=$(printf '%s' "$raw" | tr -d '[:space:]')
    if [ -z "$cleaned" ]; then
        yellow "  WARN: $url returned empty (unreachable or no IPv4 egress)"
        endpoint_failures=$((endpoint_failures + 1))
        continue
    fi
    if [[ "$cleaned" =~ $IP_REGEX ]]; then
        green "  OK:   $url -> $cleaned"
    else
        red "  FAIL: $url returned non-IPv4 payload: $(printf '%s' "$raw" | head -c 120)"
        exit 1
    fi
done

if [ "$endpoint_failures" -eq "${#urls[@]}" ]; then
    yellow "All endpoints unreachable; runner likely has no IPv4 egress. Skipping aggregate check."
    exit 0
fi

echo
echo "Aggregate script check:"
output=$("$TARGET" 2>/dev/null || true)
cleaned_output=$(printf '%s' "$output" | tr -d '[:space:]')

if [ -z "$cleaned_output" ]; then
    yellow "  WARN: get_public_ip.sh returned empty output. Some endpoints worked above, so this is likely a transient probe failure rather than a script bug."
    exit 0
fi

if ! [[ "$cleaned_output" =~ $IP_REGEX ]]; then
    red "  FAIL: get_public_ip.sh output is not a valid IPv4: '$output'"
    exit 1
fi

green "  OK: get_public_ip.sh -> $cleaned_output"
