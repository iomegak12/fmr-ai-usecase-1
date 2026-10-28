#!/usr/bin/env bash
# Usage: scripts/format.sh [goal|txn|all ...]
#
# Rewrites source files to the project formatting rules:
#   goal  Spotless apply (google-java-format)
#   txn   Ruff import sorting fix, then Ruff format
# With no project, formats both. The gateway has no Lua formatter; luacheck
# (scripts/lint.sh gateway) checks its style.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
handle_help "${1:-}"
select_projects "goal txn" "$@"

for project in "${PROJECTS[@]}"; do
  case $project in
  goal)
    info "goal: Spotless apply"
    goal_maven spotless:apply
    ;;
  txn)
    info "txn: Ruff import sorting and format"
    txn_uv run --locked ruff check --select I --fix .
    txn_uv run --locked ruff format .
    ;;
  esac
done
info "format finished: ${PROJECTS[*]}"
