#!/usr/bin/env bash
# Usage: scripts/test.sh [goal|txn|gateway|all ...]
#
# Runs the unit tests only, without coverage gates or lint:
#   goal     Maven test phase (JUnit, Mockito, AssertJ)
#   txn      pytest, with coverage collection turned off
#   gateway  busted, in the gateway test image
# With no project, tests all three. Unit tests start no database, Redis or
# network service. Use scripts/coverage.sh to enforce the coverage gates.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
handle_help "${1:-}"
select_projects "goal txn gateway" "$@"

for project in "${PROJECTS[@]}"; do
  case $project in
  goal)
    info "goal: unit tests"
    goal_maven -Dspotless.check.skip=true -Djacoco.skip=true test
    ;;
  txn)
    info "txn: unit tests"
    txn_uv run --locked pytest --no-cov
    ;;
  gateway)
    info "gateway: unit tests"
    gateway_run 'busted --no-coverage'
    ;;
  esac
done
info "tests passed: ${PROJECTS[*]}"
