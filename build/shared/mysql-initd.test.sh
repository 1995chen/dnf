#!/bin/bash
# mysql-initd.sh 就绪测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TARGET="${SCRIPT_PATH}/mysql-initd.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
cat >"$WORK/bin/mysqladmin" <<'MOCK'
#!/bin/bash
case "$MOCK_MODE" in
up) echo "mysqld is alive"; exit 0 ;;
authfail)
    echo "mysqladmin: connect to server at 'localhost' failed" >&2
    echo "error: 'Access denied for user 'root'@'localhost' (using password: NO)'" >&2
    exit 1 ;;
down)
    echo "mysqladmin: connect to server at 'localhost' failed" >&2
    echo "error: 'Can't connect to local MySQL server through socket' (2)" >&2
    exit 1 ;;
*) exit 1 ;;
esac
MOCK
chmod +x "$WORK/bin/mysqladmin"

export MYSQLADMIN="$WORK/bin/mysqladmin"
export SOCKET="$WORK/mysql.sock"
export MYSQL_START_MAX_TRIES=2
export MYSQL_START_SLEEP=0

# shellcheck source=mysql-initd.sh
source "$TARGET"

failed=0
pass=0
ok() {
    local d="$1"
    shift
    if "$@" >"$WORK/o" 2>&1; then pass=$((pass + 1)); else
        printf "FAIL %-50s (expected exit 0)\n" "$d"
        failed=$((failed + 1))
    fi
}
no() {
    local d="$1"
    shift
    if "$@" >"$WORK/o" 2>&1; then
        printf "FAIL %-50s (expected non-zero)\n" "$d"
        failed=$((failed + 1))
    else pass=$((pass + 1)); fi
}
hasout() {
    local d="$1" n="$2"
    if grep -qF -- "$n" "$WORK/o"; then pass=$((pass + 1)); else
        printf "FAIL %-50s (missing %q)\n" "$d" "$n"
        failed=$((failed + 1))
    fi
}

echo "== sourcing does not execute the init dispatcher =="
if declare -f mysql_initd_wait >/dev/null; then pass=$((pass + 1)); else
    echo "FAIL mysql_initd_wait not defined after source"
    failed=$((failed + 1))
fi

echo "== server answering the socket ping: ready =="
MOCK_MODE=up ok "up alive ready" mysql_initd_wait

echo "== server up but auth rejected: still ready (responded) =="
MOCK_MODE=authfail ok "access-denied counts as ready" mysql_initd_wait

echo "== unreachable server times out =="
MOCK_MODE=down no "cannot-connect times out" mysql_initd_wait
hasout "timeout message" "mysql failed to start within"

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
