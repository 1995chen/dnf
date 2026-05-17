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

test_ghcr_delete_via_gh_api() {
  local tmp output_file rc
  if ! tmp=$(mktemp -d); then
    fail "failed to create test directory"
  fi
  trap 'rm -rf "$tmp"' RETURN

  if ! : > "${tmp}/keep"; then
    fail "failed to write empty keep list"
  fi

  if ! cat > "${tmp}/fake-gh" <<'SCRIPT'
#!/usr/bin/env bash
if [ "$1" = "api" ] && [ "$2" = "/users/llnut" ]; then
  printf 'User\n'
  exit 0
fi
if [ "$1" = "api" ] && [ "$2" = "--paginate" ]; then
  printf '%s\t%s\n' 11 "debian13-server-qf1031-dev-abc1234"
  printf '%s\t%s\n' 12 ""
  printf '%s\t%s\n' 13 "debian13-server-qf1031-dev-abc1234,debian13-server-qf1031-dev-latest"
  exit 0
fi
if [ "$1" = "api" ] && [ "$2" = "--silent" ] && [ "$3" = "-X" ] && [ "$4" = "DELETE" ]; then
  printf 'deleted %s\n' "$5" >> "GH_DELLOG"
  exit 0
fi
exit 9
SCRIPT
  then
    fail "failed to write fake gh"
  fi
  sed -i "s#GH_DELLOG#${tmp}/dellog#" "${tmp}/fake-gh"
  if ! chmod +x "${tmp}/fake-gh"; then
    fail "failed to make fake gh executable"
  fi

  GH_BIN="${tmp}/fake-gh"
  DRY_RUN=false
  SELECTED=0
  DELETED=0
  FAILED=0
  output_file="${tmp}/output"

  delete_stale_ghcr "ghcr.io/llnut/dnf" "${tmp}/keep" "$tmp" > "$output_file" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "delete_stale_ghcr should not return ${rc}"
  fi

  assert_eq "1" "$SELECTED" "only the all-stale tagged version is selected"
  assert_eq "1" "$DELETED" "the stale version is deleted via gh api"
  assert_eq "0" "$FAILED" "no failures expected"
  assert_file_contains "deleted /users/llnut/packages/container/dnf/versions/11" "${tmp}/dellog" "version 11 deleted by id"
  assert_file_contains "skip version id=13" "$output_file" "mixed-tag version is skipped"
  if [ -f "${tmp}/dellog" ] && grep -q "versions/12" "${tmp}/dellog"; then
    fail "untagged version 12 must never be deleted"
  fi
  passed=$((passed + 1))
}

test_prune_repo_ghcr_uses_gh_not_regctl() {
  local tmp output_file rc
  if ! tmp=$(mktemp -d); then
    fail "failed to create test directory"
  fi
  trap 'rm -rf "$tmp"' RETURN

  if ! : > "${tmp}/keep"; then
    fail "failed to write empty keep list"
  fi

  if ! cat > "${tmp}/fake-gh" <<'SCRIPT'
#!/usr/bin/env bash
if [ "$1" = "api" ] && [ "$2" = "/users/llnut" ]; then
  printf 'User\n'
  exit 0
fi
if [ "$1" = "api" ] && [ "$2" = "--paginate" ]; then
  printf '%s\t%s\n' 11 "debian13-server-qf1031-dev-abc1234"
  printf '%s\t%s\n' 12 ""
  exit 0
fi
if [ "$1" = "api" ] && [ "$2" = "--silent" ] && [ "$3" = "-X" ] && [ "$4" = "DELETE" ]; then
  printf 'deleted %s\n' "$5" >> "GH_DELLOG"
  exit 0
fi
exit 9
SCRIPT
  then
    fail "failed to write fake gh"
  fi
  sed -i "s#GH_DELLOG#${tmp}/dellog#" "${tmp}/fake-gh"
  if ! chmod +x "${tmp}/fake-gh"; then
    fail "failed to make fake gh executable"
  fi

  if ! cat > "${tmp}/fake-regctl" <<'SCRIPT'
#!/usr/bin/env bash
printf 'regctl called: %s\n' "$*" >> "RGLOG"
exit 2
SCRIPT
  then
    fail "failed to write fake regctl"
  fi
  sed -i "s#RGLOG#${tmp}/rglog#" "${tmp}/fake-regctl"
  if ! chmod +x "${tmp}/fake-regctl"; then
    fail "failed to make fake regctl executable"
  fi

  GH_BIN="${tmp}/fake-gh"
  REGCTL_BIN="${tmp}/fake-regctl"
  DRY_RUN=false
  SELECTED=0
  DELETED=0
  FAILED=0
  output_file="${tmp}/output"

  prune_repo "ghcr.io/llnut/dnf" "${tmp}/keep" "$tmp" > "$output_file" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "prune_repo ghcr should return 0, got ${rc}"
  fi

  if [ -f "${tmp}/rglog" ]; then
    fail "regctl must never be invoked for a ghcr repo: $(cat "${tmp}/rglog")"
  fi
  passed=$((passed + 1))
  assert_eq "1" "$SELECTED" "ghcr stale version selected via prune_repo"
  assert_eq "1" "$DELETED" "ghcr stale version deleted via gh api"
  assert_eq "0" "$FAILED" "no failures for ghcr prune_repo"
  assert_file_contains "deleted /users/llnut/packages/container/dnf/versions/11" "${tmp}/dellog" "gh api DELETE fired for version 11"
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
test_ghcr_delete_via_gh_api
test_prune_repo_ghcr_uses_gh_not_regctl
test_delete_is_verified_after_regctl_success
test_no_implicit_pipeline_error_mode
test_workflow_verifies_regctl_checksum

echo "pass=$passed failed=0"
