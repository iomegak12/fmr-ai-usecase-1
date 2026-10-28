# ADR-0010: Stop immediately on Ctrl+C or SIGTERM, and clean up

- **Status:** Accepted
- **Date:** 2026-10-28
- **Decision register:** D-20
- **LLD impact:** New behaviour; add a shutdown section to the LLD

## Context

Graceful shutdown waits for in-flight requests, which keeps a developer's
Ctrl+C and every `docker compose down` waiting. Requests here are short,
the services keep no in-memory state, and the Transaction Service's
cross-service writes cannot be made atomic by waiting anyway (LLD §23).
What matters is that pools, clients and open transactions are closed
cleanly and that the log shows it.

## Decision

- **Goal Service.**
  - `server.shutdown: immediate`.
  - A `ContextClosedEvent` listener logs the shutdown, and Spring closes
    JPA, Hikari and executors.
  - The JVM shutdown hook handles Ctrl+C and SIGTERM.
- **Transaction Service.**
  - Uvicorn handles SIGINT and SIGTERM with `timeout_graceful_shutdown=0`.
  - The lifespan disposes of the engine and closes the httpx client, then
    logs it.
  - Open sessions are rolled back when cancelled.
- **Gateway.**
  - It stops with SIGQUIT (`STOPSIGNAL`), bounded by
    `worker_shutdown_timeout 5s`.
  - Each worker logs `event=gateway_worker_stopped` after releasing its
    Redis pool.
- **Compose and images.**
  - Grace periods are short: 5 seconds for the services and Redis, and
    8 seconds for the gateway.
  - Images run the process as PID 1 (`exec`), so signals reach it.

## Consequences

- `docker compose down` takes about 2.4 seconds for the full stack. The
  Goal JVM exits with 143, the normal status after SIGTERM, once its
  resources are closed.
- A request in flight at shutdown can be cut off. For a Transaction write,
  the Goal Service may already have applied the change. That is the same
  uncertain outcome as a timeout: it is logged as `remoteOutcome=unknown`
  for manual triage, never retried automatically (`TROUBLESHOOTING.md`).

## References

- `services/goal-service/.../common/lifecycle/ServiceLifecycle.java`,
  `application.yml`
- `services/transaction-service/app/__main__.py`, `app/common/lifecycle.py`
- `gateway/conf/nginx.conf`, `gateway/Dockerfile`, `docker-compose.yml`
