# Bake configuration for the multi-OS image set: base, db, server, full.
# CI env vars populate the variables. Defaults allow local invocation.

variable "OS" {
  default = "debian13"
}

variable "BASE_TAG" {
  default = ""
}

variable "DB_TAG" {
  default = ""
}

variable "BASE_TAGS_CSV" {
  default = ""
}

variable "DB_TAGS_CSV" {
  default = ""
}

variable "SERVER_TAGS_CSV" {
  default = ""
}

variable "FULL_TAGS_CSV" {
  default = ""
}

variable "CACHE_REPO" {
  default = "ghcr.io/llnut/dnf-cache"
}

variable "CACHE_SLUG" {
  default = "main"
}

variable "CACHE_FALLBACK_SLUG" {
  default = "main"
}

function "tag_list" {
  params = [csv]
  result = compact(split(",", csv))
}

# Targets must be invoked explicitly: db / server depend on a published base image,
# and full depends on a published db image, so a "build all" group would fail.

target "base" {
  context    = "."
  dockerfile = "build/${OS}/Dockerfile.base"
  tags       = tag_list(BASE_TAGS_CSV)
  cache-from = [
    "type=registry,ref=${CACHE_REPO}:${OS}-base-${CACHE_SLUG}",
    "type=registry,ref=${CACHE_REPO}:${OS}-base-${CACHE_FALLBACK_SLUG}",
    "type=gha,scope=${OS}-base",
  ]
  cache-to = [
    "type=registry,ref=${CACHE_REPO}:${OS}-base-${CACHE_SLUG},mode=max,ignore-error=true",
    "type=gha,mode=max,scope=${OS}-base,ignore-error=true",
  ]
}

target "db" {
  context    = "."
  dockerfile = "build/${OS}/Dockerfile.db"
  tags       = tag_list(DB_TAGS_CSV)
  args = {
    BASE_TAG = BASE_TAG
  }
  cache-from = [
    "type=registry,ref=${CACHE_REPO}:${OS}-db-${CACHE_SLUG}",
    "type=registry,ref=${CACHE_REPO}:${OS}-db-${CACHE_FALLBACK_SLUG}",
    "type=gha,scope=${OS}-db",
  ]
  cache-to = [
    "type=registry,ref=${CACHE_REPO}:${OS}-db-${CACHE_SLUG},mode=max,ignore-error=true",
    "type=gha,mode=max,scope=${OS}-db,ignore-error=true",
  ]
}

# On debian13, ubuntu26, and alma9, server and full share the dnf-compat-layer
# rust builder stage. They reuse each other's cached builder layers across runs.
# centos7 has neither builder stage; its Dockerfiles are single-FROM. The cross-
# reference would never match, so the conditional removes it to avoid noise.
target "server" {
  context    = "."
  dockerfile = "build/${OS}/Dockerfile.server"
  tags       = tag_list(SERVER_TAGS_CSV)
  args = {
    BASE_TAG = BASE_TAG
  }
  cache-from = concat(
    [
      "type=registry,ref=${CACHE_REPO}:${OS}-server-${CACHE_SLUG}",
      "type=registry,ref=${CACHE_REPO}:${OS}-server-${CACHE_FALLBACK_SLUG}",
      "type=gha,scope=${OS}-server",
    ],
    OS == "centos7" ? [] : [
      "type=registry,ref=${CACHE_REPO}:${OS}-full-${CACHE_SLUG}",
      "type=registry,ref=${CACHE_REPO}:${OS}-full-${CACHE_FALLBACK_SLUG}",
    ]
  )
  cache-to = [
    "type=registry,ref=${CACHE_REPO}:${OS}-server-${CACHE_SLUG},mode=max,ignore-error=true",
    "type=gha,mode=max,scope=${OS}-server,ignore-error=true",
  ]
}

target "full" {
  context    = "."
  dockerfile = "build/${OS}/Dockerfile.full"
  tags       = tag_list(FULL_TAGS_CSV)
  args = {
    DB_TAG = DB_TAG
  }
  cache-from = concat(
    [
      "type=registry,ref=${CACHE_REPO}:${OS}-full-${CACHE_SLUG}",
      "type=registry,ref=${CACHE_REPO}:${OS}-full-${CACHE_FALLBACK_SLUG}",
      "type=gha,scope=${OS}-full",
    ],
    OS == "centos7" ? [] : [
      "type=registry,ref=${CACHE_REPO}:${OS}-server-${CACHE_SLUG}",
      "type=registry,ref=${CACHE_REPO}:${OS}-server-${CACHE_FALLBACK_SLUG}",
    ]
  )
  cache-to = [
    "type=registry,ref=${CACHE_REPO}:${OS}-full-${CACHE_SLUG},mode=max,ignore-error=true",
    "type=gha,mode=max,scope=${OS}-full,ignore-error=true",
  ]
}

# Build db and server concurrently inside one buildkit invocation.
# Both targets share the same FROM base image, so buildkit pulls and holds its
# layers only once. The resource profiles do not overlap: db is IO and network
# bound for the mysql binary download; server is CPU bound for the rust compile.
group "middle" {
  targets = ["db", "server"]
}
