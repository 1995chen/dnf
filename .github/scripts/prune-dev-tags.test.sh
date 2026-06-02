#!/usr/bin/env bash
# shellcheck disable=SC2034

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

    if ! printf '%s\n' "dev-def5678" >"${tmp}/keep"; then
        fail "failed to write keep list"
    fi
    if ! cat >"${tmp}/tags" <<'TAGS'; then
debian13-base-dev-abc1234
debian13-base-dev-def5678
debian13-base-dev-latest
debian13-base-20260514
alma9-server-qf1031-dev-abc1234
centos7-qf1031-dev-def5678
centos7-full-qf1031-dev-abc1234
unknown-dev-abc1234
TAGS
        fail "failed to write tag list"
    fi

    local actual
    if ! actual=$(plan_stale_tags "${tmp}/keep" <"${tmp}/tags"); then
        fail "failed to plan stale tags"
    fi
    assert_lines_eq $'alma9-server-qf1031-dev-abc1234\ncentos7-full-qf1031-dev-abc1234\ndebian13-base-dev-abc1234' "$actual" "only old known dev commit tags are selected"
}

test_registry_repos() {
    local actual ACR_REGISTRY
    IMAGE_PATH=llnut/dnf

    ACR_REGISTRY=cr.example.com
    if ! actual=$(registry_repos); then
        fail "failed to build registry repo list with ACR_REGISTRY set"
    fi
    assert_lines_eq $'llnut/dnf\nghcr.io/llnut/dnf\nquay.io/llnut/dnf' "$actual" "ACR is excluded even when ACR_REGISTRY is set"

    ACR_REGISTRY=
    if ! actual=$(registry_repos); then
        fail "failed to build registry repo list"
    fi
    assert_lines_eq $'llnut/dnf\nghcr.io/llnut/dnf\nquay.io/llnut/dnf' "$actual" "registry refs are docker hub, ghcr and quay only"
}

write_fake_gh() {
    local tmp=$1

    if ! cat >"${tmp}/fake-gh" <<'SCRIPT'; then
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
        fail "failed to write fake gh"
    fi
    sed -i "s#GH_DELLOG#${tmp}/dellog#" "${tmp}/fake-gh"
    if ! chmod +x "${tmp}/fake-gh"; then
        fail "failed to make fake gh executable"
    fi
}

test_ghcr_delete_via_gh_api() {
    local tmp output_file rc
    if ! tmp=$(mktemp -d); then
        fail "failed to create test directory"
    fi
    trap 'rm -rf "$tmp"' RETURN

    if ! : >"${tmp}/keep"; then
        fail "failed to write empty keep list"
    fi
    write_fake_gh "$tmp"

    GH_BIN="${tmp}/fake-gh"
    DRY_RUN=false
    SELECTED=0
    DELETED=0
    FAILED=0
    output_file="${tmp}/output"

    delete_stale_ghcr "ghcr.io/llnut/dnf" "${tmp}/keep" "$tmp" >"$output_file" 2>&1
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

test_prune_repo_ghcr_routes_to_gh_api() {
    local tmp output_file rc
    if ! tmp=$(mktemp -d); then
        fail "failed to create test directory"
    fi
    trap 'rm -rf "$tmp"' RETURN

    if ! : >"${tmp}/keep"; then
        fail "failed to write empty keep list"
    fi
    write_fake_gh "$tmp"

    GH_BIN="${tmp}/fake-gh"
    DRY_RUN=false
    SELECTED=0
    DELETED=0
    FAILED=0
    output_file="${tmp}/output"

    prune_repo "ghcr.io/llnut/dnf" "${tmp}/keep" "$tmp" >"$output_file" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
        fail "prune_repo ghcr should return 0, got ${rc}"
    fi

    assert_eq "1" "$SELECTED" "ghcr stale version selected via prune_repo"
    assert_eq "1" "$DELETED" "ghcr stale version deleted via gh api"
    assert_eq "0" "$FAILED" "no failures for ghcr prune_repo"
    assert_file_contains "deleted /users/llnut/packages/container/dnf/versions/11" "${tmp}/dellog" "gh api DELETE fired for version 11"
}

write_fake_quay_curl() {
    local tmp=$1

    if ! cat >"${tmp}/fake-curl" <<'SCRIPT'; then
#!/usr/bin/env bash
out=""
method="GET"
url=""
prev=""
for arg in "$@"; do
  case "$prev" in
  -o) out="$arg" ;;
  -X) method="$arg" ;;
  esac
  prev="$arg"
  url="$arg"
done
state="QSTATE"
dellog="QDELLOG"
if [ "$method" = "DELETE" ]; then
  tag="${url##*/tag/}"
  if [ -f "$state" ]; then
    grep -vFx "$tag" "$state" >"${state}.tmp"
    mv "${state}.tmp" "$state"
  fi
  printf 'DELETE %s\n' "$tag" >>"$dellog"
  printf '204'
  exit 0
fi
{
  printf '{"tags":['
  first=1
  if [ -f "$state" ]; then
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      if [ "$first" -eq 0 ]; then printf ','; fi
      printf '{"name":"%s"}' "$t"
      first=0
    done <"$state"
  fi
  printf '],"has_additional":false}'
} >"$out"
printf '200'
exit 0
SCRIPT
        fail "failed to write fake curl"
    fi
    sed -i "s#QSTATE#${tmp}/state#; s#QDELLOG#${tmp}/dellog#" "${tmp}/fake-curl"
    if ! chmod +x "${tmp}/fake-curl"; then
        fail "failed to make fake curl executable"
    fi
}

write_fake_dockerhub_curl() {
    local tmp=$1

    if ! cat >"${tmp}/fake-curl" <<'SCRIPT'; then
#!/usr/bin/env bash
out=""
method="GET"
url=""
prev=""
for arg in "$@"; do
  case "$prev" in
  -o) out="$arg" ;;
  -X) method="$arg" ;;
  esac
  prev="$arg"
  url="$arg"
done
state="DHSTATE"
dellog="DHDELLOG"
noremove="DHNOREMOVE"
case "$url" in
*/users/login/)
  printf '{"token":"fake-jwt"}' >"$out"
  printf '200'
  exit 0
  ;;
esac
if [ "$method" = "DELETE" ]; then
  tag="${url%/}"
  tag="${tag##*/tags/}"
  if [ ! -f "$noremove" ] && [ -f "$state" ]; then
    grep -vFx "$tag" "$state" >"${state}.tmp"
    mv "${state}.tmp" "$state"
  fi
  printf 'DELETE %s\n' "$tag" >>"$dellog"
  printf '204'
  exit 0
fi
{
  printf '{"results":['
  first=1
  if [ -f "$state" ]; then
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      if [ "$first" -eq 0 ]; then printf ','; fi
      printf '{"name":"%s"}' "$t"
      first=0
    done <"$state"
  fi
  printf '],"next":null}'
} >"$out"
printf '200'
exit 0
SCRIPT
        fail "failed to write fake dockerhub curl"
    fi
    sed -i "s#DHSTATE#${tmp}/state#; s#DHDELLOG#${tmp}/dellog#; s#DHNOREMOVE#${tmp}/no-remove#" "${tmp}/fake-curl"
    if ! chmod +x "${tmp}/fake-curl"; then
        fail "failed to make fake dockerhub curl executable"
    fi
}

seed_tag_state() {
    local tmp=$1
    if ! printf '%s\n' \
        "debian13-base-dev-abc1234" \
        "debian13-base-dev-latest" \
        "debian13-base-20260514" >"${tmp}/state"; then
        fail "failed to seed tag state"
    fi
    if ! : >"${tmp}/keep"; then
        fail "failed to write empty keep list"
    fi
}

test_quay_delete_via_api() {
    local tmp output_file rc
    if ! tmp=$(mktemp -d); then
        fail "failed to create test directory"
    fi
    trap 'rm -rf "$tmp"' RETURN

    seed_tag_state "$tmp"
    write_fake_quay_curl "$tmp"

    CURL_BIN="${tmp}/fake-curl"
    QUAY_API_TOKEN="test-token"
    QUAY_API_BASE="https://quay.io/api/v1"
    DRY_RUN=false
    DELETE_VERIFY_ATTEMPTS=1
    DELETE_VERIFY_SLEEP=0
    SELECTED=0
    DELETED=0
    FAILED=0
    output_file="${tmp}/output"

    delete_stale_quay "quay.io/llnut/dnf" "${tmp}/keep" "$tmp" >"$output_file" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
        fail "delete_stale_quay should not return ${rc}"
    fi

    assert_eq "1" "$SELECTED" "only the stale dev commit tag is selected"
    assert_eq "1" "$DELETED" "the stale tag is deleted via the quay api"
    assert_eq "0" "$FAILED" "no failures expected for quay api delete"
    assert_file_contains "DELETE debian13-base-dev-abc1234" "${tmp}/dellog" "quay api DELETE fired for the stale tag"
    if [ -f "${tmp}/dellog" ] && grep -q "dev-latest" "${tmp}/dellog"; then
        fail "dev-latest must never be deleted"
    fi
}

test_prune_repo_quay_routes_to_api() {
    local tmp output_file rc
    if ! tmp=$(mktemp -d); then
        fail "failed to create test directory"
    fi
    trap 'rm -rf "$tmp"' RETURN

    seed_tag_state "$tmp"
    write_fake_quay_curl "$tmp"

    CURL_BIN="${tmp}/fake-curl"
    QUAY_API_TOKEN="test-token"
    QUAY_API_BASE="https://quay.io/api/v1"
    DRY_RUN=false
    DELETE_VERIFY_ATTEMPTS=1
    DELETE_VERIFY_SLEEP=0
    SELECTED=0
    DELETED=0
    FAILED=0
    output_file="${tmp}/output"

    prune_repo "quay.io/llnut/dnf" "${tmp}/keep" "$tmp" >"$output_file" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
        fail "prune_repo quay should return 0, got ${rc}"
    fi

    assert_eq "1" "$SELECTED" "quay stale tag selected via prune_repo"
    assert_eq "1" "$DELETED" "quay stale tag deleted via the quay api"
    assert_eq "0" "$FAILED" "no failures for quay prune_repo"
    assert_file_contains "DELETE debian13-base-dev-abc1234" "${tmp}/dellog" "quay api DELETE fired through prune_repo"
}

test_dockerhub_delete_via_api() {
    local tmp output_file rc
    if ! tmp=$(mktemp -d); then
        fail "failed to create test directory"
    fi
    trap 'rm -rf "$tmp"' RETURN

    seed_tag_state "$tmp"
    write_fake_dockerhub_curl "$tmp"

    CURL_BIN="${tmp}/fake-curl"
    DOCKERHUB_USERNAME="test-user"
    DOCKERHUB_TOKEN="test-token"
    DOCKERHUB_JWT=""
    DRY_RUN=false
    DELETE_VERIFY_ATTEMPTS=1
    DELETE_VERIFY_SLEEP=0
    SELECTED=0
    DELETED=0
    FAILED=0
    output_file="${tmp}/output"

    prune_repo "llnut/dnf" "${tmp}/keep" "$tmp" >"$output_file" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
        fail "prune_repo docker hub should return 0, got ${rc}"
    fi

    assert_eq "1" "$SELECTED" "only the stale dev commit tag is selected"
    assert_eq "1" "$DELETED" "the stale tag is deleted via the docker hub api"
    assert_eq "0" "$FAILED" "no failures expected for docker hub api delete"
    assert_file_contains "DELETE debian13-base-dev-abc1234" "${tmp}/dellog" "docker hub api DELETE fired for the stale tag"
    if [ -f "${tmp}/dellog" ] && grep -q "dev-latest" "${tmp}/dellog"; then
        fail "dev-latest must never be deleted"
    fi
}

test_dockerhub_delete_verification_failure() {
    local tmp output_file rc
    if ! tmp=$(mktemp -d); then
        fail "failed to create test directory"
    fi
    trap 'rm -rf "$tmp"' RETURN

    seed_tag_state "$tmp"
    write_fake_dockerhub_curl "$tmp"
    if ! : >"${tmp}/no-remove"; then
        fail "failed to write no-remove marker"
    fi

    CURL_BIN="${tmp}/fake-curl"
    DOCKERHUB_USERNAME="test-user"
    DOCKERHUB_TOKEN="test-token"
    DOCKERHUB_JWT=""
    DRY_RUN=false
    DELETE_VERIFY_ATTEMPTS=1
    DELETE_VERIFY_SLEEP=0
    SELECTED=0
    DELETED=0
    FAILED=0
    output_file="${tmp}/output"

    delete_stale_dockerhub "llnut/dnf" "${tmp}/keep" "$tmp" >"$output_file" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
        fail "delete_stale_dockerhub should aggregate failures instead of returning ${rc}"
    fi

    assert_eq "1" "$SELECTED" "stale tag should be selected"
    assert_eq "0" "$DELETED" "delete should not count before verification"
    assert_eq "1" "$FAILED" "tag still present after delete should count as failure"
    assert_file_contains "still exists after delete" "$output_file" "missing verification failure message"
}

test_quay_listing_http_error_aggregates_failure() {
    local tmp output_file
    if ! tmp=$(mktemp -d); then
        fail "failed to create test directory"
    fi
    trap 'rm -rf "$tmp"' RETURN

    if ! : >"${tmp}/keep"; then
        fail "failed to write empty keep list"
    fi

    if ! cat >"${tmp}/fake-curl" <<'SCRIPT'; then
#!/usr/bin/env bash
out=""
prev=""
for arg in "$@"; do
  case "$prev" in
  -o) out="$arg" ;;
  esac
  prev="$arg"
done
if [ -n "$out" ]; then
  printf '{"error":"boom"}' >"$out"
fi
printf '500'
exit 0
SCRIPT
        fail "failed to write fake curl"
    fi
    if ! chmod +x "${tmp}/fake-curl"; then
        fail "failed to make fake curl executable"
    fi

    CURL_BIN="${tmp}/fake-curl"
    QUAY_API_TOKEN="test-token"
    QUAY_API_BASE="https://quay.io/api/v1"
    DRY_RUN=false
    SELECTED=0
    DELETED=0
    FAILED=0
    output_file="${tmp}/output"

    delete_stale_quay "quay.io/llnut/dnf" "${tmp}/keep" "$tmp" >"$output_file" 2>&1

    assert_eq "1" "$FAILED" "a listing http error must aggregate one failure"
    assert_eq "0" "$DELETED" "nothing is deleted when listing fails"
    assert_file_contains "returned HTTP 500" "$output_file" "http error must be surfaced"
}

test_quay_delete_404_is_benign() {
    local tmp output_file
    if ! tmp=$(mktemp -d); then
        fail "failed to create test directory"
    fi
    trap 'rm -rf "$tmp"' RETURN

    seed_tag_state "$tmp"

    if ! cat >"${tmp}/fake-curl" <<'SCRIPT'; then
#!/usr/bin/env bash
out=""
method="GET"
url=""
prev=""
for arg in "$@"; do
  case "$prev" in
  -o) out="$arg" ;;
  -X) method="$arg" ;;
  esac
  prev="$arg"
  url="$arg"
done
state="QSTATE"
if [ "$method" = "DELETE" ]; then
  printf '404'
  exit 0
fi
{
  printf '{"tags":['
  first=1
  if [ -f "$state" ]; then
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      if [ "$first" -eq 0 ]; then printf ','; fi
      printf '{"name":"%s"}' "$t"
      first=0
    done <"$state"
  fi
  printf '],"has_additional":false}'
} >"$out"
printf '200'
exit 0
SCRIPT
        fail "failed to write fake curl"
    fi
    sed -i "s#QSTATE#${tmp}/state#" "${tmp}/fake-curl"
    if ! chmod +x "${tmp}/fake-curl"; then
        fail "failed to make fake curl executable"
    fi

    CURL_BIN="${tmp}/fake-curl"
    QUAY_API_TOKEN="test-token"
    QUAY_API_BASE="https://quay.io/api/v1"
    DRY_RUN=false
    DELETE_VERIFY_ATTEMPTS=1
    DELETE_VERIFY_SLEEP=0
    SELECTED=0
    DELETED=0
    FAILED=0
    output_file="${tmp}/output"

    delete_stale_quay "quay.io/llnut/dnf" "${tmp}/keep" "$tmp" >"$output_file" 2>&1

    assert_eq "1" "$SELECTED" "the stale tag is still selected"
    assert_eq "1" "$DELETED" "a 404 on delete counts as already gone"
    assert_eq "0" "$FAILED" "a 404 on delete must not be a failure"
    assert_file_contains "already absent" "$output_file" "404 path must log already absent"
}

test_quay_paginates_until_has_additional_false() {
    local tmp output_file
    if ! tmp=$(mktemp -d); then
        fail "failed to create test directory"
    fi
    trap 'rm -rf "$tmp"' RETURN

    if ! : >"${tmp}/keep"; then
        fail "failed to write empty keep list"
    fi

    if ! cat >"${tmp}/fake-curl" <<'SCRIPT'; then
#!/usr/bin/env bash
out=""
url=""
prev=""
for arg in "$@"; do
  case "$prev" in
  -o) out="$arg" ;;
  esac
  prev="$arg"
  url="$arg"
done
case "$url" in
*"page=1"*) printf '{"tags":[{"name":"debian13-base-dev-aaaaaaa"}],"has_additional":true}' >"$out" ;;
*"page=2"*) printf '{"tags":[{"name":"debian13-base-dev-bbbbbbb"}],"has_additional":false}' >"$out" ;;
*)          printf '{"tags":[],"has_additional":false}' >"$out" ;;
esac
printf '200'
exit 0
SCRIPT
        fail "failed to write fake curl"
    fi
    if ! chmod +x "${tmp}/fake-curl"; then
        fail "failed to make fake curl executable"
    fi

    CURL_BIN="${tmp}/fake-curl"
    QUAY_API_TOKEN="test-token"
    QUAY_API_BASE="https://quay.io/api/v1"
    DRY_RUN=true
    SELECTED=0
    DELETED=0
    FAILED=0
    output_file="${tmp}/output"

    delete_stale_quay "quay.io/llnut/dnf" "${tmp}/keep" "$tmp" >"$output_file" 2>&1

    assert_eq "2" "$SELECTED" "stale tags from both pages are selected"
    assert_eq "0" "$FAILED" "pagination over two pages must not fail"
    assert_file_contains "debian13-base-dev-aaaaaaa" "$output_file" "page 1 stale tag reached the plan"
    assert_file_contains "debian13-base-dev-bbbbbbb" "$output_file" "page 2 stale tag reached the plan"
}

test_dockerhub_missing_credentials_aggregates_failure() {
    local tmp output_file
    if ! tmp=$(mktemp -d); then
        fail "failed to create test directory"
    fi
    trap 'rm -rf "$tmp"' RETURN

    if ! : >"${tmp}/keep"; then
        fail "failed to write empty keep list"
    fi

    if ! CURL_BIN=$(command -v true); then
        fail "failed to resolve a no-op curl stand-in"
    fi
    DOCKERHUB_USERNAME=""
    DOCKERHUB_TOKEN=""
    DOCKERHUB_JWT=""
    DRY_RUN=false
    SELECTED=0
    DELETED=0
    FAILED=0
    output_file="${tmp}/output"

    delete_stale_dockerhub "llnut/dnf" "${tmp}/keep" "$tmp" >"$output_file" 2>&1

    assert_eq "1" "$FAILED" "missing docker hub credentials must aggregate one failure"
    assert_eq "0" "$DELETED" "nothing is deleted without credentials"
    assert_file_contains "DOCKERHUB_USERNAME and DOCKERHUB_TOKEN are required" "$output_file" "missing-credential error must be surfaced"
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

test_cleanup_no_longer_depends_on_regctl() {
    local workflow_file script_file grep_rc
    workflow_file="${SCRIPT_DIR}/../workflows/dev-tag-cleanup.yml"
    script_file="${SCRIPT_DIR}/prune-dev-tags.sh"

    grep -qi "regctl\|regclient" "$workflow_file" "$script_file"
    grep_rc=$?
    if [ "$grep_rc" -eq 0 ]; then
        fail "regctl must no longer be referenced by the cleanup workflow or script"
    fi
    if [ "$grep_rc" -ne 1 ]; then
        fail "failed to scan for regctl references"
    fi
    passed=$((passed + 1))
}

test_workflow_passes_registry_tokens() {
    local workflow_file
    workflow_file="${SCRIPT_DIR}/../workflows/dev-tag-cleanup.yml"

    assert_file_contains "QUAY_API_TOKEN:" "$workflow_file" "workflow must pass QUAY_API_TOKEN to the prune step"
    assert_file_contains "DOCKERHUB_USERNAME:" "$workflow_file" "workflow must pass DOCKERHUB_USERNAME to the prune step"
    assert_file_contains "DOCKERHUB_TOKEN:" "$workflow_file" "workflow must pass DOCKERHUB_TOKEN to the prune step"
}

test_dev_suffix_detection
test_stale_tag_planning
test_registry_repos
test_ghcr_delete_via_gh_api
test_prune_repo_ghcr_routes_to_gh_api
test_quay_delete_via_api
test_prune_repo_quay_routes_to_api
test_dockerhub_delete_via_api
test_dockerhub_delete_verification_failure
test_quay_listing_http_error_aggregates_failure
test_quay_delete_404_is_benign
test_quay_paginates_until_has_additional_false
test_dockerhub_missing_credentials_aggregates_failure
test_no_implicit_pipeline_error_mode
test_cleanup_no_longer_depends_on_regctl
test_workflow_passes_registry_tokens

echo "pass=$passed failed=0"
