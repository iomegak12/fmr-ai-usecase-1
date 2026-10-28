#!/usr/bin/env bash
# Usage: scripts/lint.sh [goal|txn|gateway|all ...]
#
# Runs the lint and format checks without changing any file:
#   goal     Spotless check (google-java-format)
#   txn      Ruff check and Ruff format --check
#   gateway  luacheck, in the gateway test image
# With no project, checks all three. Exits non-zero on the first failure.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
handle_help "${1:-}"
select_projects "goal txn gateway" "$@"

for project in "${PROJECTS[@]}"; do
  case $project in
  goal)
    info "goal: Spotless check"
    goal_maven spotless:check
    ;;
  txn)
    info "txn: Ruff check and format check"
    txn_uv run --locked ruff check .
    txn_uv run --locked ruff format --check .
    ;;
  gateway)
    info "gateway: luacheck"
    gateway_run 'luacheck lua spec'
    ;;
  esac
done
info "lint passed: ${PROJECTS[*]}"
