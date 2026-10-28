#!/usr/bin/env bash
# Usage: scripts/setup.sh
#
# Prepares a development machine:
# 1. Checks the tools. Docker with Compose v2 is required. uv (Transaction
#    Service), GNU Make, curl and Java 25 are reported when missing; without
#    Java 25 the Goal Service builds in Docker instead.
# 2. Copies each missing .env from its .env.example (root, both services and
#    the gateway). Blank GOAL_DB_PASSWORD and TXN_DB_PASSWORD values get a
#    random development password, the same in every file, reusing one already
#    set in an existing .env. Existing .env files are never changed, and
#    passwords are never printed.
# 3. Installs the Transaction Service's locked dependencies (uv sync --locked).

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
handle_help "${1:-}"
[ $# -eq 0 ] || usage_error "setup takes no arguments"

errors=0
report() { printf '  %-10s %s\n' "$1" "$2"; }

info "Checking tools"
if command -v docker >/dev/null 2>&1; then
  report docker "ok ($(docker version --format '{{.Client.Version}}' 2>/dev/null || echo unknown))"
  if compose_version=$(docker compose version --short 2>/dev/null); then
    report compose "ok ($compose_version)"
  else
    report compose "MISSING: Docker Compose v2 is required"
    errors=$((errors + 1))
  fi
  docker info >/dev/null 2>&1 || report daemon "not running: start Docker before 'make up' or the tests"
else
  report docker "MISSING: Docker is required (images, stack, gateway tests)"
  errors=$((errors + 1))
fi
if command -v uv >/dev/null 2>&1; then
  report uv "ok ($(uv --version | cut -d' ' -f2))"
else
  report uv "missing: needed for Transaction lint, tests and host runs"
fi
if command -v make >/dev/null 2>&1; then
  report make "ok ($(make --version | head -n 1))"
else
  report make "missing: run the scripts in scripts/ directly"
fi
if command -v curl >/dev/null 2>&1; then
  report curl ok
else
  report curl "missing: needed by wait-for-ready"
fi
java=$(java_major)
if [ "$java" -ge 25 ]; then
  report java "ok ($java)"
else
  report java "Java 25 not found (found ${java/#0/none}): Goal builds and runs use Docker"
fi

info "Creating missing .env files"
ENV_DIRS=("$KALASH_ROOT" "$GOAL_DIR" "$TXN_DIR" "$GATEWAY_DIR")

# Prints a password already set in any existing .env, or a new random one.
password_for() {
  local dir value
  for dir in "${ENV_DIRS[@]}"; do
    value=$(dotenv_get "$dir/.env" "$1")
    if [ -n "$value" ]; then
      printf '%s' "$value"
      return
    fi
  done
  od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
}
goal_password=$(password_for GOAL_DB_PASSWORD)
txn_password=$(password_for TXN_DB_PASSWORD)

for dir in "${ENV_DIRS[@]}"; do
  name=${dir#"$KALASH_ROOT"}
  name=${name#/}
  name=${name:+$name/}.env
  if [ -f "$dir/.env" ]; then
    report kept "$name (unchanged)"
    continue
  fi
  awk -v goal="$goal_password" -v txn="$txn_password" '
    { sub(/\r$/, "") }
    $0 == "GOAL_DB_PASSWORD=" { $0 = $0 goal }
    $0 == "TXN_DB_PASSWORD=" { $0 = $0 txn }
    { print }' "$dir/.env.example" >"$dir/.env.tmp"
  on_windows || chmod 600 "$dir/.env.tmp"
  mv "$dir/.env.tmp" "$dir/.env"
  report created "$name"
done

if command -v uv >/dev/null 2>&1; then
  info "Installing Transaction Service dependencies"
  txn_uv sync --locked
fi

[ "$errors" -eq 0 ] || die "$errors required tool(s) missing"
info "Setup finished. Next: 'make up' for the full stack, or 'make help'."
