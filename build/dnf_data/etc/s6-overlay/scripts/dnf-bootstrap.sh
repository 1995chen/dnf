#!/bin/bash

init_path=/etc/s6-overlay/scripts/init.d
for step in 10-env-resolve 20-cleanup 30-init-data; do
    echo "[dnf-bootstrap] running ${step}"
    if ! "${init_path}/${step}.sh"; then
        echo "[dnf-bootstrap] ${step} failed" >&2
        exit 1
    fi
done
echo "[dnf-bootstrap] all init steps done"
