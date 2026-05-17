#!/usr/bin/env bash

if ! SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); then
  echo "FAIL: failed to resolve script directory" >&2
  exit 1
fi

passed=0

fail() {
  echo "FAIL $*" >&2
  exit 1
}

# shellcheck source=.github/scripts/prune-dev-tags.sh
if ! . "${SCRIPT_DIR}/prune-dev-tags.sh"; then
  fail "failed to load prune-dev-tags.sh"
fi

assert_eq() {
  local expected=$1
  local actual=$2
  local message=$3
  if [ "$expected" != "$actual" ]; then
    fail "${message}: expected '${expected}', got '${actual}'"
  fi
  passed=$((passed + 1))
}

assert_lines_eq() {
  local expected=$1
  local actual=$2
  local message=$3
  if [ "$expected" != "$actual" ]; then
    printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
    fail "$message"
  fi
  passed=$((passed + 1))
}

assert_file_contains() {
  local pattern=$1
  local file=$2
  local message=$3
  local grep_rc

  grep -q -- "$pattern" "$file"
  grep_rc=$?
  if [ "$grep_rc" -eq 0 ]; then
    passed=$((passed + 1))
    return 0
  fi
  if [ "$grep_rc" -eq 1 ]; then
    fail "$message"
  fi
  fail "failed to read ${file}"
}

assert_dev_suffix() {
  local expected=$1
  local tag=$2
  local message=$3
  local actual

  if ! actual=$(dev_suffix_for_tag "$tag"); then
    fail "failed to inspect tag ${tag}"
  fi
  assert_eq "$expected" "$actual" "$message"
}

test_dev_suffix_detection() {
  assert_dev_suffix "dev-abc1234" "debian13-base-dev-abc1234" "base dev tag"
  assert_dev_suffix "dev-abc1234" "ubuntu26-db-dev-abc1234" "db dev tag"
  assert_dev_suffix "dev-abc1234" "alma9-server-qf1031-dev-abc1234" "server dev tag"
  assert_dev_suffix "dev-abc1234" "centos7-qf1031-dev-abc1234" "full dev tag"
  assert_dev_suffix "dev-abc1234" "centos7-full-qf1031-dev-abc1234" "full alias dev tag"
  assert_dev_suffix "" "debian13-base-dev-latest" "dev-latest must not be treated as a commit tag"
  assert_dev_suffix "" "debian13-base-latest" "release latest must not be treated as a dev tag"
  assert_dev_suffix "" "debian13-base-20260514" "release tag must not be treated as a dev tag"
}

test_stale_tag_planning() {
  local tmp
  if ! tmp=$(mktemp -d); then
    fail "failed to create test directory"
  fi
  trap 'rm -rf "$tmp"' RETURN

  if ! printf '%s\n' "dev-def5678" > "${tmp}/keep"; then
    fail "failed to write keep list"
  fi
  if ! cat > "${tmp}/tags" <<'TAGS'
debian13-base-dev-abc1234
debian13-base-dev-def5678
debian13-base-dev-latest
debian13-base-20260514
alma9-server-qf1031-dev-abc1234
centos7-qf1031-dev-def5678
centos7-full-qf1031-dev-abc1234
unknown-dev-abc1234
TAGS
  then
    fail "failed to write tag list"
  fi

  local actual
  if ! actual=$(plan_stale_tags "${tmp}/keep" < "${tmp}/tags"); then
    fail "failed to plan stale tags"
  fi
  assert_lines_eq $'alma9-server-qf1031-dev-abc1234\ncentos7-full-qf1031-dev-abc1234\ndebian13-base-dev-abc1234' "$actual" "only old known dev commit tags are selected"
}

test_registry_repos() {
  local actual
  IMAGE_PATH=llnut/dnf
  ACR_REGISTRY=cr.example.com
  if ! actual=$(registry_repos); then
    fail "failed to build registry repo list with ACR"
  fi
  assert_lines_eq $'llnut/dnf\nghcr.io/llnut/dnf\nquay.io/llnut/dnf\ncr.example.com/llnut/dnf' "$actual" "registry refs include ACR when configured"

  ACR_REGISTRY=
  if ! actual=$(registry_repos); then
    fail "failed to build registry repo list without ACR"
  fi
  assert_lines_eq $'llnut/dnf\nghcr.io/llnut/dnf\nquay.io/llnut/dnf' "$actual" "registry refs skip empty ACR"
}

test_delete_is_verified_after_regctl_success() {
  local tmp output_file rc
  if ! tmp=$(mktemp -d); then
    fail "failed to create test directory"
  fi
  trap 'rm -rf "$tmp"' RETURN

  if ! : > "${tmp}/keep"; then
    fail "failed to write empty keep list"
  fi

  if ! cat > "${tmp}/fake-regctl" <<'SCRIPT'
#!/usr/bin/env bash
if [ "$1" = "tag" ] && [ "$2" = "ls" ]; then
  printf '%s\n' "debian13-base-dev-abc1234"
  exit 0
fi

if [ "$1" = "tag" ] && [ "$2" = "delete" ]; then
  exit 0
fi

exit 2
SCRIPT
  then
    fail "failed to write fake regctl"
  fi
  if ! chmod +x "${tmp}/fake-regctl"; then
    fail "failed to make fake regctl executable"
  fi

  REGCTL_BIN="${tmp}/fake-regctl"
  DRY_RUN=false
  DELETE_VERIFY_ATTEMPTS=1
  DELETE_VERIFY_SLEEP=0
  SELECTED=0
  DELETED=0
  FAILED=0
  output_file="${tmp}/output"

  prune_repo "example.com/repo" "${tmp}/keep" "$tmp" > "$output_file" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "prune_repo should aggregate failures instead of returning ${rc}"
  fi

  assert_eq "1" "$SELECTED" "stale tag should be selected"
  assert_eq "0" "$DELETED" "delete should not count before verification"
  assert_eq "1" "$FAILED" "tag still present after delete should count as failure"
  assert_file_contains "still exists after delete" "$output_file" "missing verification failure message"
}

test_no_implicit_pipeline_error_mode() {
  local needle
  local workflow_file
  local grep_rc
  needle="pipe""fail"
  workflow_file="${SCRIPT_DIR}/../workflows/dev-tag-cleanup.yml"

  grep -n -- "$needle" "${SCRIPT_DIR}/prune-dev-tags.sh" "${SCRIPT_DIR}/prune-dev-tags.test.sh" "$workflow_file"
  grep_rc=$?
  if [ "$grep_rc" -eq 0 ]; then
    fail "explicit error handling should be used instead of ${needle}"
  fi
  if [ "$grep_rc" -ne 1 ]; then
    fail "failed to scan for disallowed shell option"
  fi
}

test_workflow_verifies_regctl_checksum() {
  local workflow_file
  workflow_file="${SCRIPT_DIR}/../workflows/dev-tag-cleanup.yml"

  assert_file_contains "REGCTL_SHA256:" "$workflow_file" "workflow must pin regctl checksum"
  assert_file_contains "sha256sum -c" "$workflow_file" "workflow must verify regctl checksum"
}

test_dev_suffix_detection
test_stale_tag_planning
test_registry_repos
test_delete_is_verified_after_regctl_success
test_no_implicit_pipeline_error_mode
test_workflow_verifies_regctl_checksum

echo "pass=$passed failed=0"
