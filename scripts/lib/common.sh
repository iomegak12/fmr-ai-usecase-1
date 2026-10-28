# shellcheck shell=bash
# Shared helpers for the Kalash Bash scripts. Source this file; do not run it.
#
# Sets strict mode, the repository paths and the tool images, and provides
# logging, project selection, .env reading, and the Goal (Maven) and gateway
# (busted/luacheck) runners used by several scripts.

set -euo pipefail

# Git Bash would otherwise rewrite container paths such as /workspace.
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'

KALASH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GOAL_DIR="$KALASH_ROOT/services/goal-service"
TXN_DIR="$KALASH_ROOT/services/transaction-service"
GATEWAY_DIR="$KALASH_ROOT/gateway"
# shellcheck disable=SC2034 # used by backup.sh and restore.sh
COMPOSE_FILE_ROOT="$KALASH_ROOT/docker-compose.yml"

# Same Maven/JDK image as the Goal Dockerfile's build stage.
MAVEN_IMAGE="${MAVEN_IMAGE:-maven:3.9.11-eclipse-temurin-25}"
GOAL_MAVEN_CACHE="${GOAL_MAVEN_CACHE:-kalash-goal-maven-cache}"
GATEWAY_TEST_IMAGE="${GATEWAY_TEST_IMAGE:-kalash/gateway-test}"

info() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# Prints the calling script's header comment (its usage text).
usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

usage_error() {
  printf 'error: %s\n\n' "$*" >&2
  usage >&2
  exit 2
}

# Exits with the usage text when the first argument asks for help.
handle_help() {
  case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  esac
}

on_windows() {
  case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) return 0 ;;
  *) return 1 ;;
  esac
}

# Converts a path for Docker's --mount source (Windows paths under Git Bash).
host_path() {
  if on_windows; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

# select_projects "<allowed>" [requested...] sets PROJECTS. No request, or
# "all", selects every allowed project.
select_projects() {
  local allowed=$1 project
  shift
  PROJECTS=()
  if [ $# -eq 0 ] || { [ $# -eq 1 ] && [ "$1" = all ]; }; then
    read -r -a PROJECTS <<<"$allowed"
    return
  fi
  for project in "$@"; do
    case " $allowed " in
    *" $project "*) PROJECTS+=("$project") ;;
    *) usage_error "unknown project '$project' (expected: $allowed or all)" ;;
    esac
  done
}

# dotenv_get <file> <key>: prints the key's value from a .env file, if present.
# Values are read as text and never evaluated.
dotenv_get() {
  local file=$1 key=$2 line
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    case $line in "$key="*)
      strip_quotes "${line#*=}"
      return 0
      ;;
    esac
  done <"$file"
}

strip_quotes() {
  local value=$1
  if [[ $value =~ ^\"(.*)\"$ || $value =~ ^\'(.*)\'$ ]]; then value=${BASH_REMATCH[1]}; fi
  printf '%s' "$value"
}

# setting <key> <default>: the environment wins, then the root .env, then the default.
setting() {
  local key=$1 default=$2 value
  value=${!key:-}
  [ -n "$value" ] || value=$(dotenv_get "$KALASH_ROOT/.env" "$key")
  printf '%s' "${value:-$default}"
}

# load_env_file <file>: exports each KEY=VALUE without evaluating it. Variables
# already set in the environment win, as they do for pydantic-settings.
# ENV_KEYS lists every key the file defines.
load_env_file() {
  local file=$1 line key
  ENV_KEYS=()
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    case $line in '' | '#'*) continue ;; esac
    key=${line%%=*}
    [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    ENV_KEYS+=("$key")
    [ -n "${!key+set}" ] || export "$key=$(strip_quotes "${line#*=}")"
  done <"$file"
}

java_major() {
  local java=java version
  [ -z "${JAVA_HOME:-}" ] || java="$JAVA_HOME/bin/java"
  version=$("$java" -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p' | head -n 1) || true
  printf '%s' "${version:-0}"
}

# Sets GOAL_MODE to host (Java 25+ available) or docker. GOAL_RUNNER=host or
# docker forces one.
resolve_goal_runner() {
  case "${GOAL_RUNNER:-auto}" in
  host | docker) GOAL_MODE=$GOAL_RUNNER ;;
  auto) if [ "$(java_major)" -ge 25 ]; then GOAL_MODE=host; else GOAL_MODE=docker; fi ;;
  *) die "GOAL_RUNNER must be auto, host or docker" ;;
  esac
}

# Docker flags for an interactive terminal, when there is one.
tty_flags() {
  if [ -t 0 ] && [ -t 1 ]; then printf '%s' '-it'; fi
}

# goal_maven <maven args...>: runs the Maven Wrapper with Java 25, on the host
# or in the Maven image. On Linux, files the container writes are handed back
# to the calling user.
goal_maven() {
  resolve_goal_runner
  if [ "$GOAL_MODE" = host ]; then
    (cd "$GOAL_DIR" && sh ./mvnw -B "$@")
    return
  fi
  local uid='' gid=''
  if ! on_windows; then
    uid=$(id -u)
    gid=$(id -g)
  fi
  info "Running Maven with Java 25 in $MAVEN_IMAGE (host Java is $(java_major))"
  docker run --rm -e "HOST_UID=$uid" -e "HOST_GID=$gid" \
    --mount "type=bind,source=$(host_path "$GOAL_DIR"),target=/workspace" \
    --mount "type=volume,source=$GOAL_MAVEN_CACHE,target=/root/.m2" \
    -w /workspace "$MAVEN_IMAGE" \
    sh -c 'sh ./mvnw -B $*; s=$?; ${HOST_UID:+chown -R $HOST_UID:$HOST_GID target} 2>/dev/null; exit $s' \
    sh "$@"
}

# gateway_run '<shell command>': runs a command in the gateway test image
# (busted, luacheck, luacov) against the working tree, without a network.
gateway_run() {
  info "Building $GATEWAY_TEST_IMAGE"
  docker build --quiet --target test -t "$GATEWAY_TEST_IMAGE" "$(host_path "$GATEWAY_DIR")" >/dev/null
  docker run --rm --network none \
    --mount "type=bind,source=$(host_path "$GATEWAY_DIR"),target=/gateway" \
    "$GATEWAY_TEST_IMAGE" sh -c "$1"
}

# txn_uv <uv args...>: runs uv from the Transaction Service directory.
txn_uv() {
  command -v uv >/dev/null 2>&1 || die "uv is required for the Transaction Service; run 'make setup'"
  (cd "$TXN_DIR" && uv "$@")
}
