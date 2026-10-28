#!/usr/bin/env bash
# Usage: scripts/run.sh goal|txn
#
# Runs one service on the host in the foreground with its local profile and
# coloured console logs. Press Ctrl+C to stop it.
#   goal  Loads services/goal-service/.env into the process environment
#         (Spring does not read .env), builds the jar and runs it with
#         Java 25. Without Java 25 it runs in the Maven image instead,
#         publishing GOAL_SERVICE_PORT; a localhost database is then
#         reached through host.docker.internal.
#   txn   uv run python -m app; the service reads its own .env. Apply
#         migrations first with scripts/migrate.sh.
# The service's database must already be running, for example from
# 'make up' or the project's own compose file.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
handle_help "${1:-}"
[ $# -eq 1 ] || usage_error "name exactly one service"
SKIP_CHECKS=(-Dmaven.test.skip=true -Dspotless.check.skip=true -Djacoco.skip=true)

case $1 in
goal)
  [ -f "$GOAL_DIR/.env" ] || die "services/goal-service/.env is missing; run 'make setup'"
  load_env_file "$GOAL_DIR/.env"
  export SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-local}"
  resolve_goal_runner
  if [ "$GOAL_MODE" = host ]; then
    goal_maven -q "${SKIP_CHECKS[@]}" package
    cd "$GOAL_DIR"
    jar=$(ls target/goal-service-*.jar)
    info "goal: starting $jar"
    exec java -jar "$jar"
  fi
  case ${GOAL_DB_HOST:-localhost} in
  localhost | 127.0.0.1) export GOAL_DB_HOST=host.docker.internal ;;
  esac
  port=${GOAL_SERVICE_PORT:-8080}
  env_args=()
  for key in "${ENV_KEYS[@]}" SPRING_PROFILES_ACTIVE GOAL_DB_HOST; do env_args+=(-e "$key"); done
  info "goal: building and starting in $MAVEN_IMAGE on port $port"
  # -e NAME copies the value from this process, so no secret is on the command line.
  # shellcheck disable=SC2046
  exec docker run --rm $(tty_flags) --name kalash-goal-run -p "$port:$port" \
    --add-host host.docker.internal:host-gateway "${env_args[@]}" \
    --mount "type=bind,source=$(host_path "$GOAL_DIR"),target=/workspace" \
    --mount "type=volume,source=$GOAL_MAVEN_CACHE,target=/root/.m2" \
    -w /workspace "$MAVEN_IMAGE" \
    sh -c 'sh ./mvnw -B -q $* package && exec java -jar target/goal-service-*.jar' \
    sh "${SKIP_CHECKS[@]}"
  ;;
txn)
  [ -f "$TXN_DIR/.env" ] || die "services/transaction-service/.env is missing; run 'make setup'"
  command -v uv >/dev/null 2>&1 || die "uv is required for the Transaction Service; run 'make setup'"
  cd "$TXN_DIR"
  info "txn: starting with uv"
  exec uv run --locked python -m app
  ;;
*) usage_error "unknown service '$1' (expected goal or txn)" ;;
esac
