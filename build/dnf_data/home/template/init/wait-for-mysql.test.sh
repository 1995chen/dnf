#!/bin/bash
# wait-for-mysql.sh 测试：服务端有应答即就绪，不验证凭据，鉴权失败也算
# 就绪，只有不可达才超时。

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TARGET="${SCRIPT_PATH}/wait-for-mysql.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

# mock mysqladmin：up 表示服务端应答，down 表示不可达。
cat >"$WORK/bin/mysqladmin" <<'MOCK'
#!/bin/bash
case "$MOCK_MODE" in
up) echo "mysqld is alive"; exit 0 ;;
authfail)
    echo "mysqladmin: connect to server at '127.0.0.1' failed" >&2
    echo "error: 'Access denied for user 'root'@'localhost' (using password: NO)'" >&2
    exit 1 ;;
down)
    echo "mysqladmin: connect to server at '127.0.0.1' failed" >&2
    echo "error: 'Can't connect to MySQL server on '127.0.0.1' (111)'" >&2
    exit 1 ;;
*) exit 1 ;;
esac
MOCK
chmod +x "$WORK/bin/mysqladmin"
export PATH="$WORK/bin:$PATH"
export WAIT_FOR_MYSQL_RETRY_INTERVAL=0

failed=0
pass=0
run() { MOCK_MODE="$1" bash "$TARGET" 127.0.0.1 4000 "$2" "${3:-3}" 0 >"$WORK/o" 2>&1; }
ok() {
    local d="$1"
    shift
    if "$@"; then pass=$((pass + 1)); else
        printf "FAIL %-48s (expected exit 0)\n" "$d"
        failed=$((failed + 1))
    fi
}
no() {
    local d="$1"
    shift
    if "$@"; then
        printf "FAIL %-48s (expected non-zero)\n" "$d"
        failed=$((failed + 1))
    else pass=$((pass + 1)); fi
}
hasout() {
    local d="$1" n="$2"
    if grep -qF -- "$n" "$WORK/o"; then pass=$((pass + 1)); else
        printf "FAIL %-48s (missing %q)\n" "$d" "$n"
        failed=$((failed + 1))
    fi
}

echo "== server answering: ready regardless of credentials =="
ok "up alive ready" run up secret 3
hasout "ready message" "mysql is ready"

echo "== server up but auth rejected: still ready (responded) =="
ok "access-denied counts as ready" run authfail secret 3
ok "access-denied with empty pw ready" run authfail "" 3

echo "== unreachable server times out =="
no "cannot-connect times out" run down secret 2
hasout "timeout error message" "did not become ready"

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
