#!/usr/bin/env bash

IMAGE_PATH=${IMAGE_PATH:-llnut/dnf}
RETENTION_DAYS=${RETENTION_DAYS:-30}
DRY_RUN=${DRY_RUN:-false}
GH_BIN=${GH_BIN:-gh}
CURL_BIN=${CURL_BIN:-curl}
QUAY_API_BASE=${QUAY_API_BASE:-https://quay.io/api/v1}
QUAY_API_TOKEN=${QUAY_API_TOKEN:-}
QUAY_TAG_PAGE_LIMIT=${QUAY_TAG_PAGE_LIMIT:-100}
DOCKERHUB_API_BASE=${DOCKERHUB_API_BASE:-https://hub.docker.com/v2}
DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME:-}
DOCKERHUB_TOKEN=${DOCKERHUB_TOKEN:-}
DOCKERHUB_TAG_PAGE_LIMIT=${DOCKERHUB_TAG_PAGE_LIMIT:-100}
DOCKERHUB_JWT=${DOCKERHUB_JWT:-}
DELETE_VERIFY_ATTEMPTS=${DELETE_VERIFY_ATTEMPTS:-3}
DELETE_VERIFY_SLEEP=${DELETE_VERIFY_SLEEP:-3}

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
            if ! printf '%s\n' "$tag" >>"$unsorted"; then
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

    if ! git log --since="${RETENTION_DAYS} days ago" --format=%H >"$commits_file"; then
        error "failed to read git history for the last ${RETENTION_DAYS} day(s)"
        rm -f "$commits_file" "$suffixes_file"
        return 1
    fi

    if ! awk 'length($0) >= 7 { print "dev-" substr($0, 1, 7) }' "$commits_file" >"$suffixes_file"; then
        error "failed to build recent dev suffix list"
        rm -f "$commits_file" "$suffixes_file"
        return 1
    fi

    if ! sort -u "$suffixes_file" >"$keep_file"; then
        error "failed to sort recent dev suffix list"
        rm -f "$commits_file" "$suffixes_file"
        return 1
    fi

    rm -f "$commits_file" "$suffixes_file"
}

is_true() {
    case "${1,,}" in
    1 | true | yes | y | on) return 0 ;;
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

write_auth_header() {
    local file=$1 value=$2

    if ! printf 'Authorization: %s\n' "$value" >"$file"; then
        error "failed to write auth header file ${file}"
        return 1
    fi

    return 0
}

verify_tag_deleted() {
    local repo=$1 tag=$2 tmp_dir=$3 lister=$4
    local attempt repo_key tags_file grep_rc

    repo_key=${repo//\//_}
    repo_key=${repo_key//:/_}
    tags_file="${tmp_dir}/${repo_key}.verify.tags"

    attempt=1
    while [ "$attempt" -le "$DELETE_VERIFY_ATTEMPTS" ]; do
        # Wait before each check so the registry can propagate the delete.
        if ! sleep "$DELETE_VERIFY_SLEEP"; then
            error "failed while waiting to verify ${repo}:${tag}"
            return 1
        fi

        if ! "$lister" "$repo" "$tags_file"; then
            return 1
        fi

        grep -qFx "$tag" "$tags_file"
        grep_rc=$?
        if [ "$grep_rc" -eq 1 ]; then
            return 0
        fi
        if [ "$grep_rc" -ne 0 ]; then
            error "failed to inspect verification tag list for ${repo}"
            return 1
        fi

        if [ "$attempt" -lt "$DELETE_VERIFY_ATTEMPTS" ]; then
            echo "  tag still visible after delete, retrying verification (${attempt}/${DELETE_VERIFY_ATTEMPTS})"
        fi

        attempt=$((attempt + 1))
    done

    echo "  tag still exists after delete: ${repo}:${tag}" >&2
    return 1
}

ghcr_api_base() {
    local owner=$1 pkg=$2 owner_type

    # let gh stderr through on failure so auth/scope errors are visible
    if ! owner_type=$("$GH_BIN" api "/users/${owner}" --jq '.type'); then
        return 1
    fi
    case "$(printf '%s' "$owner_type" | tr '[:upper:]' '[:lower:]')" in
    user) printf '/users/%s/packages/container/%s' "$owner" "$pkg" ;;
    organization) printf '/orgs/%s/packages/container/%s' "$owner" "$pkg" ;;
    *) return 1 ;;
    esac
}

delete_stale_ghcr() {
    local repo=$1 keep_file=$2 tmp_dir=$3
    local rest owner pkg base versions versions_err repo_key
    local id tags tag suffix has_stale keep_version
    local -a tag_arr

    if ! command -v "$GH_BIN" >/dev/null 2>&1; then
        error "required command not found: ${GH_BIN}"
        FAILED=$((FAILED + 1))
        return 0
    fi

    rest=${repo#ghcr.io/}
    owner=${rest%%/*}
    pkg=${rest#*/}

    if ! base=$(ghcr_api_base "$owner" "$pkg"); then
        error "failed to resolve GHCR package path for ${repo}"
        FAILED=$((FAILED + 1))
        return 0
    fi

    repo_key=${repo//\//_}
    repo_key=${repo_key//:/_}
    versions="${tmp_dir}/${repo_key}.versions"
    versions_err="${tmp_dir}/${repo_key}.versions.err"

    if ! "$GH_BIN" api --paginate "${base}/versions" \
        --jq '.[] | [.id, ((.metadata.container.tags // []) | join(","))] | @tsv' \
        >"$versions" 2>"$versions_err"; then
        error "failed to list package versions for ${repo}"
        cat "$versions_err" >&2
        FAILED=$((FAILED + 1))
        return 0
    fi

    while IFS=$'\t' read -r id tags; do
        [ -n "$id" ] || continue
        [ -n "${tags:-}" ] || continue

        has_stale=false
        keep_version=false
        IFS=',' read -ra tag_arr <<<"$tags"
        for tag in "${tag_arr[@]}"; do
            suffix=$(dev_suffix_for_tag "$tag")
            if [ -z "$suffix" ]; then
                keep_version=true
            elif grep -qFx "$suffix" "$keep_file"; then
                keep_version=true
            else
                has_stale=true
            fi
        done

        if [ "$has_stale" != true ]; then
            continue
        fi
        if [ "$keep_version" = true ]; then
            echo "  skip version id=${id}: also carries kept or non-dev tags (${tags})"
            continue
        fi

        SELECTED=$((SELECTED + 1))
        if is_true "$DRY_RUN"; then
            echo "  [dry-run] DELETE ${repo} version id=${id} tags=${tags}"
            continue
        fi

        echo "  DELETE ${repo} version id=${id} tags=${tags}"
        if "$GH_BIN" api --silent -X DELETE "${base}/versions/${id}"; then
            DELETED=$((DELETED + 1))
        else
            FAILED=$((FAILED + 1))
            echo "  delete failed for ${repo} version id=${id}" >&2
        fi
    done <"$versions"
}

list_quay_active_tags() {
    local repo=$1 out_file=$2
    local rest page page_file hdr_file http_code has_more page_count url

    rest=${repo#quay.io/}

    if ! : >"$out_file"; then
        error "failed to initialize quay tag list for ${repo}"
        return 1
    fi

    hdr_file="${out_file}.hdr"
    if ! write_auth_header "$hdr_file" "Bearer ${QUAY_API_TOKEN}"; then
        return 1
    fi

    page=1
    page_file="${out_file}.page"
    while true; do
        url="${QUAY_API_BASE}/repository/${rest}/tag/?onlyActiveTags=true&limit=${QUAY_TAG_PAGE_LIMIT}&page=${page}"
        if ! http_code=$("$CURL_BIN" -sS -o "$page_file" -w '%{http_code}' \
            -H "@${hdr_file}" \
            -H "Accept: application/json" \
            "$url"); then
            error "failed to query quay tags for ${repo}"
            return 1
        fi

        if [ "$http_code" != "200" ]; then
            error "quay tag listing for ${repo} returned HTTP ${http_code}"
            cat "$page_file" >&2
            return 1
        fi

        if ! jq -r '.tags[].name' "$page_file" >>"$out_file"; then
            error "failed to parse quay tag list for ${repo}"
            return 1
        fi

        page_count=$(jq -r '.tags | length' "$page_file")
        if [ "$page_count" = "0" ]; then
            break
        fi

        has_more=$(jq -r '.has_additional // false' "$page_file")
        if [ "$has_more" != "true" ]; then
            break
        fi
        page=$((page + 1))
    done

    return 0
}

delete_stale_quay() {
    local repo=$1 keep_file=$2 tmp_dir=$3
    local rest repo_key tags_file stale_file hdr_file tag http_code url

    if ! command -v "$CURL_BIN" >/dev/null 2>&1; then
        error "required command not found: ${CURL_BIN}"
        FAILED=$((FAILED + 1))
        return 0
    fi
    if ! command -v jq >/dev/null 2>&1; then
        error "required command not found: jq"
        FAILED=$((FAILED + 1))
        return 0
    fi
    if [ -z "$QUAY_API_TOKEN" ]; then
        error "QUAY_API_TOKEN is required to prune ${repo}"
        FAILED=$((FAILED + 1))
        return 0
    fi

    rest=${repo#quay.io/}
    repo_key=${repo//\//_}
    repo_key=${repo_key//:/_}
    tags_file="${tmp_dir}/${repo_key}.tags"
    stale_file="${tmp_dir}/${repo_key}.stale"
    hdr_file="${tmp_dir}/${repo_key}.auth.hdr"

    if ! write_auth_header "$hdr_file" "Bearer ${QUAY_API_TOKEN}"; then
        FAILED=$((FAILED + 1))
        return 0
    fi

    if ! list_quay_active_tags "$repo" "$tags_file"; then
        FAILED=$((FAILED + 1))
        return 0
    fi

    if ! plan_stale_tags "$keep_file" <"$tags_file" >"$stale_file"; then
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
        url="${QUAY_API_BASE}/repository/${rest}/tag/${tag}"
        if ! http_code=$("$CURL_BIN" -sS -o /dev/null -w '%{http_code}' \
            -X DELETE \
            -H "@${hdr_file}" \
            "$url"); then
            FAILED=$((FAILED + 1))
            echo "  delete request failed for ${repo}:${tag}" >&2
            continue
        fi

        case "$http_code" in
        200 | 201 | 202 | 204)
            if verify_tag_deleted "$repo" "$tag" "$tmp_dir" list_quay_active_tags; then
                DELETED=$((DELETED + 1))
            else
                FAILED=$((FAILED + 1))
            fi
            ;;
        404)
            echo "  tag already absent: ${repo}:${tag}"
            DELETED=$((DELETED + 1))
            ;;
        *)
            FAILED=$((FAILED + 1))
            echo "  delete for ${repo}:${tag} returned HTTP ${http_code}" >&2
            ;;
        esac
    done <"$stale_file"
}

dockerhub_login() {
    local tmp_dir=$1
    local req_file resp_file http_code

    if [ -n "$DOCKERHUB_JWT" ]; then
        return 0
    fi
    if [ -z "$DOCKERHUB_USERNAME" ] || [ -z "$DOCKERHUB_TOKEN" ]; then
        error "DOCKERHUB_USERNAME and DOCKERHUB_TOKEN are required to prune Docker Hub"
        return 1
    fi

    req_file="${tmp_dir}/dockerhub.login.req"
    resp_file="${tmp_dir}/dockerhub.login.resp"

    if ! jq -n --arg u "$DOCKERHUB_USERNAME" --arg p "$DOCKERHUB_TOKEN" \
        '{username: $u, password: $p}' >"$req_file"; then
        error "failed to build Docker Hub login request"
        return 1
    fi

    if ! http_code=$("$CURL_BIN" -sS -o "$resp_file" -w '%{http_code}' \
        -X POST \
        -H "Content-Type: application/json" \
        --data "@${req_file}" \
        "${DOCKERHUB_API_BASE}/users/login/"); then
        error "failed to request Docker Hub login token"
        return 1
    fi

    if [ "$http_code" != "200" ]; then
        error "Docker Hub login returned HTTP ${http_code}"
        return 1
    fi

    if ! DOCKERHUB_JWT=$(jq -r '.token // empty' "$resp_file"); then
        error "failed to parse Docker Hub login token"
        return 1
    fi

    if [ -z "$DOCKERHUB_JWT" ]; then
        error "Docker Hub login response did not contain a token"
        return 1
    fi

    return 0
}

list_dockerhub_tags() {
    local repo=$1 out_file=$2
    local page page_file hdr_file http_code next page_count url

    if ! : >"$out_file"; then
        error "failed to initialize Docker Hub tag list for ${repo}"
        return 1
    fi

    hdr_file="${out_file}.hdr"
    if ! write_auth_header "$hdr_file" "JWT ${DOCKERHUB_JWT}"; then
        return 1
    fi

    page=1
    page_file="${out_file}.page"
    while true; do
        url="${DOCKERHUB_API_BASE}/repositories/${repo}/tags/?page_size=${DOCKERHUB_TAG_PAGE_LIMIT}&page=${page}"
        if ! http_code=$("$CURL_BIN" -sS -o "$page_file" -w '%{http_code}' \
            -H "@${hdr_file}" \
            "$url"); then
            error "failed to query Docker Hub tags for ${repo}"
            return 1
        fi

        if [ "$http_code" != "200" ]; then
            error "Docker Hub tag listing for ${repo} returned HTTP ${http_code}"
            cat "$page_file" >&2
            return 1
        fi

        if ! jq -r '.results[].name' "$page_file" >>"$out_file"; then
            error "failed to parse Docker Hub tag list for ${repo}"
            return 1
        fi

        page_count=$(jq -r '.results | length' "$page_file")
        if [ "$page_count" = "0" ]; then
            break
        fi

        next=$(jq -r '.next // empty' "$page_file")
        if [ -z "$next" ]; then
            break
        fi
        page=$((page + 1))
    done

    return 0
}

delete_stale_dockerhub() {
    local repo=$1 keep_file=$2 tmp_dir=$3
    local repo_key tags_file stale_file hdr_file tag http_code url

    if ! command -v "$CURL_BIN" >/dev/null 2>&1; then
        error "required command not found: ${CURL_BIN}"
        FAILED=$((FAILED + 1))
        return 0
    fi
    if ! command -v jq >/dev/null 2>&1; then
        error "required command not found: jq"
        FAILED=$((FAILED + 1))
        return 0
    fi
    if ! dockerhub_login "$tmp_dir"; then
        FAILED=$((FAILED + 1))
        return 0
    fi

    repo_key=${repo//\//_}
    repo_key=${repo_key//:/_}
    tags_file="${tmp_dir}/${repo_key}.tags"
    stale_file="${tmp_dir}/${repo_key}.stale"
    hdr_file="${tmp_dir}/${repo_key}.auth.hdr"

    if ! write_auth_header "$hdr_file" "JWT ${DOCKERHUB_JWT}"; then
        FAILED=$((FAILED + 1))
        return 0
    fi

    if ! list_dockerhub_tags "$repo" "$tags_file"; then
        FAILED=$((FAILED + 1))
        return 0
    fi

    if ! plan_stale_tags "$keep_file" <"$tags_file" >"$stale_file"; then
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
        url="${DOCKERHUB_API_BASE}/repositories/${repo}/tags/${tag}/"
        if ! http_code=$("$CURL_BIN" -sS -o /dev/null -w '%{http_code}' \
            -X DELETE \
            -H "@${hdr_file}" \
            "$url"); then
            FAILED=$((FAILED + 1))
            echo "  delete request failed for ${repo}:${tag}" >&2
            continue
        fi

        case "$http_code" in
        200 | 202 | 204)
            if verify_tag_deleted "$repo" "$tag" "$tmp_dir" list_dockerhub_tags; then
                DELETED=$((DELETED + 1))
            else
                FAILED=$((FAILED + 1))
            fi
            ;;
        404)
            echo "  tag already absent: ${repo}:${tag}"
            DELETED=$((DELETED + 1))
            ;;
        *)
            FAILED=$((FAILED + 1))
            echo "  delete for ${repo}:${tag} returned HTTP ${http_code}" >&2
            ;;
        esac
    done <"$stale_file"
}

prune_repo() {
    local repo=$1
    local keep_file=$2
    local tmp_dir=$3

    echo "Scanning ${repo}"
    case "$repo" in
    ghcr.io/*)
        delete_stale_ghcr "$repo" "$keep_file" "$tmp_dir"
        ;;
    quay.io/*)
        delete_stale_quay "$repo" "$keep_file" "$tmp_dir"
        ;;
    *)
        delete_stale_dockerhub "$repo" "$keep_file" "$tmp_dir"
        ;;
    esac
}

main() {
    validate_retention_days
    validate_delete_verification_settings

    local keep_file repo
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
