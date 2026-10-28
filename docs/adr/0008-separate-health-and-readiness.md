# ADR-0008: Separate `/health` (liveness) from `/ready` (readiness)

- **Status:** Accepted
- **Date:** 2026-10-28
- **Decision register:** D-16 (with D-17 for readiness dependencies)
- **LLD impact:** Deviation from LLD §26, which lists one health endpoint per
  service (`/actuator/health` including the database; `/health` including a
  database check) and a gateway health check on `/`

## Context

A single health endpoint that includes the database mixes two questions.
"Is the process alive?" decides whether to restart it. "Can it serve
requests?" decides whether to send traffic or start dependants. If a
database outage fails liveness, the orchestrator restarts healthy processes
in a loop and adds load while the database recovers.

## Decision

Every component exposes both endpoints, with the same paths:

| Component | `/health` (liveness) | `/ready` (readiness) |
|---|---|---|
| Goal Service | Actuator liveness group (`livenessState`) | Readiness group: `readinessState` and `db` (`goal_db`) |
| Transaction Service | Process alive; no database access | ORM session check on `transaction_db` only |
| Gateway | Static `{"status":"UP"}` | Redis check, reported as `DEGRADED` with HTTP 200 (ADR-0005) |

- In Java these are Actuator health groups exposed with `additional-path`
  on the server port, so `/health` and `/ready` work without the
  `/actuator` prefix.
- The Transaction Service's readiness does not include the Goal Service.
  A Goal outage is handled per request (503 `TXN-002` or 504 `TXN-003`),
  and history stays available (D-17).
- The gateway passes `/health/{goals,transactions}` and
  `/ready/{goals,transactions}` through to the services.
- Docker Compose waits on `/ready` (`depends_on: service_healthy`), and the
  images' `HEALTHCHECK` uses `/health`.

## Consequences

- A database outage marks the service not ready (HTTP 503) while liveness
  stays 200, so nothing is restarted. Readiness recovers on its own.
  Verified for both services, and covered by unit tests
  (`ReadinessContextTest`, `tests/unit/health/test_router.py`).
- Response bodies show only the status, never component details.

## References

- `services/goal-service/src/main/resources/application.yml` (health groups)
- `services/transaction-service/app/health/router.py`
- `gateway/conf/conf.d/health.conf`, `gateway/lua/kalash/gateway.lua`
