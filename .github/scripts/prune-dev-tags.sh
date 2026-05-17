#!/usr/bin/env bash

IMAGE_PATH=${IMAGE_PATH:-llnut/dnf}
ACR_REGISTRY=${ACR_REGISTRY:-}
RETENTION_DAYS=${RETENTION_DAYS:-90}
DRY_RUN=${DRY_RUN:-false}
REGCTL_BIN=${REGCTL_BIN:-regctl}
DELETE_VERIFY_ATTEMPTS=${DELETE_VERIFY_ATTEMPTS:-3}
DELETE_VERIFY_SLEEP=${DELETE_VERIFY_SLEEP:-5}

OS_LIST=(debian13 ubuntu26 alma9 centos7)

error() {
  echo "::error::$*" >&2
}

dev_suffix_for_tag() {
  local tag=$1
  local os rest

  for os in "${OS_LIST[@]}"; do
    case "$tag" in
      "${os}-base-"*) rest=${tag#"${os}-base-"} ;;
      "${os}-db-"*) rest=${tag#"${os}-db-"} ;;
      "${os}-server-qf1031-"*) rest=${tag#"${os}-server-qf1031-"} ;;
      "${os}-full-qf1031-"*) rest=${tag#"${os}-full-qf1031-"} ;;
      "${os}-qf1031-"*) rest=${tag#"${os}-qf1031-"} ;;
      *) continue ;;
    esac

    if [[ "$rest" =~ ^dev-[0-9a-f]{7,40}$ ]]; then
      printf '%s\n' "$rest"
    fi
    return 0
  done

  return 0
}

registry_repos() {
  printf '%s\n' \
    "${IMAGE_PATH}" \
    "ghcr.io/${IMAGE_PATH}" \
    "quay.io/${IMAGE_PATH}"

  if [ -n "$ACR_REGISTRY" ]; then
    printf '%s\n' "${ACR_REGISTRY}/${IMAGE_PATH}"
  fi
}

plan_stale_tags() {
  local keep_file=$1
  local tag suffix
  local unsorted

  if ! unsorted=$(mktemp); then
    echo "failed to create temporary file for stale tag planning" >&2
    return 1
  fi

  while IFS= read -r tag; do
    [ -n "$tag" ] || continue

    suffix=$(dev_suffix_for_tag "$tag")
    [ -n "$suffix" ] || continue

    local grep_rc
    grep -qFx "$suffix" "$keep_file"
    grep_rc=$?

    if [ "$grep_rc" -eq 0 ]; then
      continue
    fi

    if [ "$grep_rc" -eq 1 ]; then
      if ! printf '%s\n' "$tag" >> "$unsorted"; then
        echo "failed to write stale tag plan" >&2
        rm -f "$unsorted"
        return 1
      fi
    else
      echo "failed to read keep list ${keep_file}" >&2
      rm -f "$unsorted"
      return 1
    fi
  done

  if ! sort "$unsorted"; then
    echo "failed to sort stale tag plan" >&2
    rm -f "$unsorted"
    return 1
  fi

  rm -f "$unsorted"
}

write_recent_dev_suffixes() {
  local keep_file=$1
  local commits_file suffixes_file

  if ! commits_file=$(mktemp); then
    error "failed to create temporary commit list"
    return 1
  fi
  if ! suffixes_file=$(mktemp); then
    error "failed to create temporary suffix list"
    rm -f "$commits_file"
    return 1
  fi

  if ! git log --since="${RETENTION_DAYS} days ago" --format=%H > "$commits_file"; then
    error "failed to read git history for the last ${RETENTION_DAYS} day(s)"
    rm -f "$commits_file" "$suffixes_file"
    return 1
  fi

  if ! awk 'length($0) >= 7 { print "dev-" substr($0, 1, 7) }' "$commits_file" > "$suffixes_file"; then
    error "failed to build recent dev suffix list"
    rm -f "$commits_file" "$suffixes_file"
    return 1
  fi

  if ! sort -u "$suffixes_file" > "$keep_file"; then
    error "failed to sort recent dev suffix list"
    rm -f "$commits_file" "$suffixes_file"
    return 1
  fi

  rm -f "$commits_file" "$suffixes_file"
}

is_true() {
  case "${1,,}" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

validate_retention_days() {
  if ! [[ "$RETENTION_DAYS" =~ ^[1-9][0-9]*$ ]]; then
    error "RETENTION_DAYS must be a positive integer, got '${RETENTION_DAYS}'"
    exit 1
  fi
}

validate_delete_verification_settings() {
  if ! [[ "$DELETE_VERIFY_ATTEMPTS" =~ ^[1-9][0-9]*$ ]]; then
    error "DELETE_VERIFY_ATTEMPTS must be a positive integer, got '${DELETE_VERIFY_ATTEMPTS}'"
    exit 1
  fi

  if ! [[ "$DELETE_VERIFY_SLEEP" =~ ^[0-9]+$ ]]; then
    error "DELETE_VERIFY_SLEEP must be a non-negative integer, got '${DELETE_VERIFY_SLEEP}'"
    exit 1
  fi
}

tag_exists_in_repo() {
  local repo=$1
  local tag=$2
  local tmp_dir=$3
  local repo_key tags_file grep_rc

  repo_key=${repo//\//_}
  repo_key=${repo_key//:/_}
  tags_file="${tmp_dir}/${repo_key}.verify.tags"

  if ! "$REGCTL_BIN" tag ls "$repo" > "$tags_file"; then
    error "failed to verify tags for ${repo}"
    return 2
  fi

  grep -qFx "$tag" "$tags_file"
  grep_rc=$?
  if [ "$grep_rc" -eq 0 ]; then
    return 0
  fi
  if [ "$grep_rc" -eq 1 ]; then
    return 1
  fi

  error "failed to inspect verification tag list for ${repo}"
  return 2
}

verify_tag_deleted() {
  local repo=$1
  local tag=$2
  local tmp_dir=$3
  local attempt exists_rc

  attempt=1
  while [ "$attempt" -le "$DELETE_VERIFY_ATTEMPTS" ]; do
    tag_exists_in_repo "$repo" "$tag" "$tmp_dir"
    exists_rc=$?

    if [ "$exists_rc" -eq 1 ]; then
      return 0
    fi
    if [ "$exists_rc" -ne 0 ]; then
      return 1
    fi

    if [ "$attempt" -lt "$DELETE_VERIFY_ATTEMPTS" ]; then
      echo "  tag still visible after delete, retrying verification (${attempt}/${DELETE_VERIFY_ATTEMPTS})"
      if ! sleep "$DELETE_VERIFY_SLEEP"; then
        error "failed while waiting to verify ${repo}:${tag}"
        return 1
      fi
    fi

    attempt=$((attempt + 1))
  done

  echo "  tag still exists after delete: ${repo}:${tag}" >&2
  return 1
}

prune_repo() {
  local repo=$1
  local keep_file=$2
  local tmp_dir=$3
  local repo_key tags_file stale_file tag

  repo_key=${repo//\//_}
  repo_key=${repo_key//:/_}
  tags_file="${tmp_dir}/${repo_key}.tags"
  stale_file="${tmp_dir}/${repo_key}.stale"

  echo "Scanning ${repo}"
  if ! "$REGCTL_BIN" tag ls "$repo" > "$tags_file"; then
    error "failed to list tags for ${repo}"
    FAILED=$((FAILED + 1))
    return 0
  fi

  if ! plan_stale_tags "$keep_file" < "$tags_file" > "$stale_file"; then
    error "failed to plan stale tags for ${repo}"
    FAILED=$((FAILED + 1))
    return 0
  fi

  if [ ! -s "$stale_file" ]; then
    echo "  no stale dev commit tags"
    return 0
  fi

  while IFS= read -r tag; do
    [ -n "$tag" ] || continue
    SELECTED=$((SELECTED + 1))

    if is_true "$DRY_RUN"; then
      echo "  [dry-run] DELETE ${repo}:${tag}"
      continue
    fi

    echo "  DELETE ${repo}:${tag}"
    if "$REGCTL_BIN" tag delete --ignore-missing "${repo}:${tag}"; then
      if verify_tag_deleted "$repo" "$tag" "$tmp_dir"; then
        DELETED=$((DELETED + 1))
      else
        FAILED=$((FAILED + 1))
      fi
    else
      FAILED=$((FAILED + 1))
      echo "  delete failed for ${repo}:${tag}" >&2
    fi
  done < "$stale_file"
}

main() {
  validate_retention_days
  validate_delete_verification_settings

  local keep_file repo
  if ! command -v "$REGCTL_BIN" >/dev/null 2>&1; then
    error "required command not found: ${REGCTL_BIN}"
    exit 1
  fi

  if ! tmp_dir=$(mktemp -d); then
    error "failed to create temporary directory"
    exit 1
  fi
  trap 'rm -rf "$tmp_dir"' EXIT
  keep_file="${tmp_dir}/recent-dev-suffixes"

  if ! write_recent_dev_suffixes "$keep_file"; then
    exit 1
  fi

  local keep_count
  if ! keep_count=$(awk 'END { print NR + 0 }' "$keep_file"); then
    error "failed to count recent dev suffixes"
    exit 1
  fi

  echo "retention_days: ${RETENTION_DAYS}"
  echo "dry_run:        ${DRY_RUN}"
  echo "image_path:     ${IMAGE_PATH}"
  echo "recent dev commit suffixes to keep: ${keep_count}"
  echo "---"

  SELECTED=0
  DELETED=0
  FAILED=0

  while IFS= read -r repo; do
    prune_repo "$repo" "$keep_file" "$tmp_dir"
  done < <(registry_repos)

  echo "---"
  echo "selected: ${SELECTED}"
  echo "deleted:  ${DELETED}"
  echo "failed:   ${FAILED}"

  if [ "$FAILED" -gt 0 ]; then
    error "${FAILED} registry operation(s) failed; rerun to retry"
    exit 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
