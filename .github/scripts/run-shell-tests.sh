#!/usr/bin/env bash

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_root" || exit 2

red=0
tpass=0
tfail=0

echo "== syntax: bash -n every *.sh =="
while IFS= read -r -d '' f; do
    if ! err=$(bash -n "$f" 2>&1); then
        echo "SYNTAX FAIL  $f"
        printf '%s\n' "$err" | sed 's/^/    /'
        red=1
    fi
done < <(find . -name '*.sh' -not -path './.git/*' -print0 | sort -z)

echo
echo "== scripts/binaries must be executable =="
for f in \
    build/dnf_data/etc/s6-overlay/scripts/stage2-hook.sh \
    build/dnf_data/etc/s6-overlay/scripts/mysql-init.sh \
    build/dnf_data/etc/s6-overlay/scripts/mysql-run.sh \
    build/dnf_data/etc/s6-overlay/s6-rc.d/mysql/run \
    build/dnf_data/etc/s6-overlay/scripts/on-finish \
    build/dnf_data/etc/s6-overlay/scripts/on-start \
    build/dnf_data/TeaEncrypt \
    build/dnf_data/home/template/init/scheduler/db-tool.sh \
    build/dnf_data/etc/s6-overlay/scripts/init.d/*.sh; do
    case "$f" in *.test.sh) continue ;; esac
    [ -f "$f" ] || continue
    if [ ! -x "$f" ]; then
        echo "NOT EXECUTABLE  $f"
        red=1
    fi
done

echo
echo "== unit: every *.test.sh, gated on exit code =="
while IFS= read -r -d '' t; do
    if out=$(bash "$t" 2>&1); then
        summary=$(printf '%s' "$out" | grep -oE 'pass=[0-9]+ failed=[0-9]+' | tail -n1)
        echo "PASS  ${t#./}  [${summary:-exit 0}]"
        tpass=$((tpass + 1))
    else
        echo "FAIL  ${t#./}"
        printf '%s\n' "$out" | tail -n8 | sed 's/^/    /'
        tfail=$((tfail + 1))
        red=1
    fi
done < <(find . -name '*.test.sh' -not -path './.git/*' -print0 | sort -z)

echo
echo "== shellcheck: maintained scripts, -S style =="
if command -v shellcheck >/dev/null 2>&1; then
    sc_targets=(
        .github/scripts/run-shell-tests.sh
        .github/scripts/prune-dev-tags.sh
        build/dnf_data/home/template/init/lib/s6-runprobe
        build/dnf_data/home/template/init/lib/probe-tcp-port.sh
        build/dnf_data/home/template/init/lib/probe-tcp-port.test.sh
        build/dnf_data/home/template/init/lib/probe-game-log.sh
        build/dnf_data/home/template/init/lib/probe-game-log.test.sh
        build/dnf_data/home/template/init/lib/zerg-resolve.test.sh
        build/dnf_data/etc/s6-overlay/scripts/stage2-hook.sh
        build/dnf_data/etc/s6-overlay/scripts/mysql-init.sh
        build/dnf_data/etc/s6-overlay/scripts/mysql-run.sh
        build/dnf_data/etc/s6-overlay/scripts/stage2-hook.test.sh
        build/dnf_data/etc/s6-overlay/scripts/on-finish
        build/dnf_data/etc/s6-overlay/scripts/on-finish.test.sh
        build/dnf_data/etc/s6-overlay/scripts/on-start
        build/dnf_data/etc/s6-overlay/scripts/on-start.test.sh
        build/dnf_data/etc/s6-overlay/scripts/init.d/env-resolve.sh
        build/dnf_data/etc/s6-overlay/scripts/init.d/env-resolve.test.sh
        build/dnf_data/etc/s6-overlay/scripts/init.d/cleanup.sh
        build/dnf_data/etc/s6-overlay/scripts/init.d/init-data.sh
        build/dnf_data/etc/s6-overlay/scripts/init.d/init-data.test.sh
        build/dnf_data/etc/s6-overlay/scripts/init.d/init-db.sh
        build/dnf_data/home/template/init/run/start_gate.sh
        build/dnf_data/home/template/init/lib/probe-secbus.sh
        build/dnf_data/home/template/init/lib/tune.sh
        build/dnf_data/home/template/init/lib/tune.test.sh
        build/dnf_data/home/template/init/lib/common.sh
        build/dnf_data/home/template/init/lib/common.test.sh
        build/dnf_data/home/template/init/lib/mysql.sh
        build/dnf_data/home/template/init/lib/mysql.test.sh
        build/dnf_data/home/template/init/scheduler/scheduler.sh
        build/dnf_data/home/template/init/scheduler/scheduler.test.sh
        build/dnf_data/home/template/init/scheduler/db-tool.sh
        build/dnf_data/home/template/init/scheduler/db-tool.test.sh
        build/dnf_data/home/template/init/scheduler/user-script.sh
        build/dnf_data/home/template/init/wait-for-mysql.sh
        build/dnf_data/home/template/init/monitor_ip/get_public_ip.sh
        build/dnf_data/home/template/init/monitor_ip/get_public_ip.test.sh
        build/dnf_data/home/template/init/monitor_ip/monitor_ip.sh
        build/dnf_data/home/template/init/monitor_ip/monitor_ip.test.sh
        build/dnf_data/db-entrypoint.sh
    )
    if shellcheck -s bash -S style -e SC1091 "${sc_targets[@]}"; then
        echo "shellcheck clean"
    else
        echo "shellcheck reported issues"
        red=1
    fi
else
    echo "shellcheck not installed, skipped (bash -n still enforced)"
fi

echo
echo "== summary: suites pass=${tpass} fail=${tfail} =="
exit "$red"
