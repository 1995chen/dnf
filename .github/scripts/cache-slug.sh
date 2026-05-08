#!/usr/bin/env bash

# Sanitize a single git ref name into an OCI-tag-safe cache slug.
sanitize_slug() {
  local raw="$1"
  local sanitized slug
  sanitized=$(printf '%s' "$raw" \
    | sed -e 's/[^a-zA-Z0-9._-]/-/g' \
          -e 's/^[^a-zA-Z0-9_][^a-zA-Z0-9_]*//')
  # Bash substring expansion avoids the SIGPIPE that 'head -c 50' would
  # otherwise raise upstream under set -o pipefail.
  slug="${sanitized:0:50}"
  [ -n "$slug" ] || slug="main"
  printf '%s' "$slug"
}
