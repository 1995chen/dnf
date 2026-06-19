#!/bin/bash
# s6-runprobe 的测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TARGET="${SCRIPT_PATH}/s6-runprobe"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
PROBES="$WORK/probes.d"
mkdir -p "$PROBES"

fail=0
# 用 bash 直接跑, 绕过 #!/command/with-contenv 的 shebang
run() { S6_PROBES_PATH="$PROBES" bash "$TARGET" "$1"; }
chk() {
    if [ "$2" = "$3" ]; then
        echo "ok: $1"
    else
        echo "FAIL: $1 (expected $2 got $3)"
        fail=1
    fi
}

run noexist
chk "missing probe file -> ready" 0 $?

: >"$PROBES/empty"
run empty
chk "empty probe file -> ready" 0 $?

echo data >"$WORK/marker"
echo "file:$WORK/marker" >"$PROBES/f_ok"
run f_ok
chk "file non-empty -> ready" 0 $?

echo "file:$WORK/none" >"$PROBES/f_missing"
run f_missing
chk "file missing -> not ready" 1 $?

: >"$WORK/emptyfile"
echo "file:$WORK/emptyfile" >"$PROBES/f_empty"
run f_empty
chk "file empty -> not ready" 1 $?

# 探针文件指向目录或目录软链接时不应当作就绪
mkdir -p "$WORK/adir"
echo "file:$WORK/adir" >"$PROBES/f_dir"
run f_dir
chk "file is a directory -> not ready" 1 $?

ln -s "$WORK/adir" "$WORK/dirlink"
echo "file:$WORK/dirlink" >"$PROBES/f_dirlink"
run f_dirlink
chk "file is a symlink-to-dir -> not ready" 1 $?

# 探针文件指向非空文件的软链接，就绪
ln -s "$WORK/marker" "$WORK/filelink"
echo "file:$WORK/filelink" >"$PROBES/f_filelink"
run f_filelink
chk "file is a symlink-to-nonempty-file -> ready" 0 $?

echo "cmd:true" >"$PROBES/c_ok"
run c_ok
chk "cmd true -> ready" 0 $?

echo "cmd:false" >"$PROBES/c_fail"
run c_fail
chk "cmd false -> not ready" 1 $?

# shellcheck disable=SC2016
echo 'cmd:test "$MY_PROBE_VAR" = yes' >"$PROBES/c_env"
MY_PROBE_VAR=yes S6_PROBES_PATH="$PROBES" bash "$TARGET" c_env
chk "cmd env var expand -> ready" 0 $?

printf 'foo\nREADY now\n' >"$WORK/log"
echo "logmark:$WORK/log:READY" >"$PROBES/lm"
run lm
chk "logmark hit -> ready" 0 $?

echo "logmark:$WORK/log:NOPE" >"$PROBES/lm_miss"
run lm_miss
chk "logmark miss -> not ready" 1 $?

echo "cmd:true;file:$WORK/marker" >"$PROBES/multi_ok"
run multi_ok
chk "multi all-ok -> ready" 0 $?

echo "cmd:true;cmd:false" >"$PROBES/multi_fail"
run multi_fail
chk "multi one-fail -> not ready" 1 $?

if [ "$fail" = 0 ]; then
    echo "ALL PASS"
else
    echo "SOME FAILED"
fi
exit "$fail"
