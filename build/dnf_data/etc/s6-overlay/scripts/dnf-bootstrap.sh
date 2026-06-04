#!/bin/bash

init_path="${DNF_INIT_PATH:-/etc/s6-overlay/scripts/init.d}"

run_seq() {
    echo "[dnf-bootstrap] running $1"
    if ! "${init_path}/$1.sh"; then
        echo "[dnf-bootstrap] $1 failed" >&2
        exit 1
    fi
}
for step in 10-env-resolve 20-cleanup; do
    run_seq "$step"
done

run_par() {
    "${init_path}/$1.sh" 2>&1 | sed -u "s/^/[$2] /"
    return "${PIPESTATUS[0]}"
}
echo "[dnf-bootstrap] running 30-init-data and 30-init-db in parallel"
run_par 30-init-data data &
pid_data=$!
run_par 30-init-db db &
pid_db=$!
wait "$pid_data"
rc_data=$?
wait "$pid_db"
rc_db=$?
if [ "$rc_data" -ne 0 ] || [ "$rc_db" -ne 0 ]; then
    echo "[dnf-bootstrap] parallel init failed (30-init-data=$rc_data 30-init-db=$rc_db)" >&2
    exit 1
fi

echo "[dnf-bootstrap] all init steps done"
