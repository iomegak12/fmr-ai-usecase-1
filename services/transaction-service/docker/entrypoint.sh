#!/bin/sh
# Transaction Service container entrypoint (plan Section 5.6).
#
# Applies the Alembic migrations, then replaces itself with the service
# (exec), so Uvicorn is PID 1 and receives SIGTERM/SIGINT directly for the
# immediate shutdown in D-20. A failed migration exits non-zero, so the
# service never starts against an outdated schema.
#
# Usage: docker-entrypoint            migrate, then run the service
#        docker-entrypoint <cmd...>   run another command instead, for
#                                     example `alembic current`
set -eu

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

alembic upgrade head
exec python -m app
