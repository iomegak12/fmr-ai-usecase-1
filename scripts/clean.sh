#!/usr/bin/env bash
# Usage: scripts/clean.sh [goal|txn|gateway|all ...]
#
# Removes build output, caches and coverage reports:
#   goal     target/
#   txn      pytest, Ruff and bytecode caches, coverage data and htmlcov/
#   gateway  luacov statistics and report
# With no project, cleans all three. Keeps .env files, the Transaction .venv,
# backups, Docker images and volumes.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
handle_help "${1:-}"
select_projects "goal txn gateway" "$@"

for project in "${PROJECTS[@]}"; do
  case $project in
  goal)
    info "goal: removing target/"
    rm -rf "$GOAL_DIR/target"
    ;;
  txn)
    info "txn: removing caches and coverage output"
    (
      cd "$TXN_DIR"
      rm -rf .pytest_cache .ruff_cache htmlcov .coverage .coverage.* coverage.xml
      find app tests alembic -type d -name __pycache__ -prune -exec rm -rf {} +
    )
    ;;
  gateway)
    info "gateway: removing luacov output"
    rm -f "$GATEWAY_DIR/luacov.stats.out" "$GATEWAY_DIR/luacov.report.out"
    ;;
  esac
done
info "clean finished: ${PROJECTS[*]}"
