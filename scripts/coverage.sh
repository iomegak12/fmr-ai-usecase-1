#!/usr/bin/env bash
# Usage: scripts/coverage.sh [goal|txn|gateway|all ...]
#
# Runs the unit tests with coverage and enforces the gates:
#   goal     Maven verify: JaCoCo, at least 80% line coverage
#            report: services/goal-service/target/site/jacoco/index.html
#   txn      pytest-cov, at least 80% line coverage
#            report: services/transaction-service/htmlcov/index.html
#   gateway  busted with luacov; reported, with no gate (D-23)
#            report: gateway/luacov.report.out
# With no project, covers all three.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
handle_help "${1:-}"
select_projects "goal txn gateway" "$@"

for project in "${PROJECTS[@]}"; do
  case $project in
  goal)
    info "goal: tests with the JaCoCo gate"
    goal_maven -Dspotless.check.skip=true verify
    ;;
  txn)
    info "txn: tests with the pytest-cov gate"
    txn_uv run --locked pytest --cov-report=html
    ;;
  gateway)
    info "gateway: tests with the luacov report"
    gateway_run "busted && luacov && sed -n '/^Summary/,\$p' luacov.report.out"
    ;;
  esac
done
info "coverage passed: ${PROJECTS[*]}"
