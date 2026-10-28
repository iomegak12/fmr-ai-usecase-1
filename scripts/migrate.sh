#!/usr/bin/env bash
# Usage: scripts/migrate.sh
#
# Applies the Transaction Service's Alembic migrations (alembic upgrade head)
# to the database in services/transaction-service/.env. Run it before
# 'make run-txn'. The Goal Service needs no step: Flyway migrates goal_db
# when the service starts. In Docker, the Transaction entrypoint migrates.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
handle_help "${1:-}"
[ $# -eq 0 ] || usage_error "migrate takes no arguments"
[ -f "$TXN_DIR/.env" ] || die "services/transaction-service/.env is missing; run 'make setup'"

info "txn: alembic upgrade head"
txn_uv run --locked alembic upgrade head
info "migrations applied"
