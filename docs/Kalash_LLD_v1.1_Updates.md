# LLD 1.1 Update List

**Applies to:** [Kalash LLD v1.0](Kalash_LLD_v1.0.md)
**Source:** [Implementation plan decision register](Kalash_Project_Impl_Plan_Opus_v1.0.md#3-decision-register),
[ADRs](adr/README.md) and the Release 1 implementation
**Status:** Proposed for LLD revision 1.1 (plan Open Issue 11)

Release 1 was built from the implementation plan, whose decision register
records where it deliberately differs from LLD v1.0. This list gives the LLD
author every change needed for LLD 1.1 to describe the system as built.
Part A covers the six deviations the plan names. Part B covers smaller
clarifications and contract interpretations made during implementation.
The LLD itself has not been edited.

## Part A: Required deviations

| # | Decision | LLD sections | Change for LLD 1.1 |
|---|---|---|---|
| A1 | D-04 Python packaging ([ADR-0001](adr/0001-uv-for-python-packaging.md)) | §27 image table, §28 pipeline, §31 Open Issue 6 | Replace `pip install -r requirements.txt` with uv: `pyproject.toml`, committed `uv.lock`, `uv sync --frozen --no-dev` in the image, `uv run --locked` for tools. Close Open Issue 6 with "Maven Wrapper, Spotless, Ruff, uv". |
| A2 | D-09 Gateway rate limiting with OpenResty and Redis ([ADR-0002](adr/0002-rate-limiting-at-the-gateway.md)), with D-10 to D-13 and D-15 ([ADR-0003](adr/0003-sliding-window-log.md) to [ADR-0006](adr/0006-rate-limit-only-the-public-api.md)) | §5.1 services, §5.2 versions, §18 gateway, §19 security, §24 NFRs, §27 images and compose | Add Redis 8.8 (`redis`, port 6379, not published, no persistence). Change the gateway from Nginx 1.30 to OpenResty 1.31.1.1. Add a rate-limiting section: 100 requests per rolling 60 seconds per client IP, as a sliding-window log in one atomic Redis script; a 30-second uncounted warm-up; fail-open with ERROR logging; only `/api/v1/*` limited; `real_ip` trusting only `TRUSTED_PROXIES`. Add the `RATE_LIMIT_*`, `REDIS_*` and `TRUSTED_PROXIES` settings to §6. |
| A3 | D-14 Rate-limit response ([ADR-0007](adr/0007-429-problem-details.md)) | §12 conventions, §21.2 catalogue | Add `COMMON-429`, HTTP 429, "Too many requests, please retry later", produced by the gateway. Document the `Retry-After`, `X-RateLimit-Limit`, `X-RateLimit-Remaining` and `X-RateLimit-Reset` headers; `X-RateLimit-Reset` is in seconds until capacity returns. |
| A4 | D-16 Health and readiness ([ADR-0008](adr/0008-separate-health-and-readiness.md)) | §26 monitoring, §27 compose outline | Replace "`/actuator/health` (includes DB)" and "`/health` (includes a DB check)" with `/health` for liveness (no dependencies) and `/ready` for readiness (own database only) on both services. Give the gateway its own `/health` and a `/ready` that reports Redis as `DEGRADED` with HTTP 200, plus pass-through `/health/{goals,transactions}` and `/ready/{goals,transactions}`. Health checks use `/health`; `depends_on: service_healthy` waits on `/ready`. Replace "Nginx: container health check on `/`". |
| A5 | D-18 API documentation through the gateway ([ADR-0009](adr/0009-api-documentation-through-the-gateway.md)) | §13 API contracts, §18 gateway | List the documentation endpoints: Goal `/swagger-ui` and `/v3/api-docs`; Transaction `/docs` and `/openapi.json`. Add gateway routes `/docs/goals/` and `/docs/transactions/`, which forward documentation paths only with `X-Forwarded-Prefix`, are not rate limited, and need `APP_ROOT_PATH=/docs/transactions` on the Transaction Service. |
| A6 | D-23 Testing scope | §30 testing approach, §28 pipeline | Release 1 has unit tests only: JUnit Jupiter 6.0.3 (JUnit 5 API) with Mockito and AssertJ, pytest with respx, busted with luacheck. JaCoCo and pytest-cov gate at 80% line coverage; luacov reports with no gate. Move Spring Boot Test with Testcontainers, pytest with Testcontainers, and the "unit + integration" pipeline steps to a later release. Close Open Issue 9 with "Spring Boot 4.1.2 manages Jupiter 6.0.3". |

## Part B: Clarifications from implementation

| # | LLD sections | Change for LLD 1.1 | Source |
|---|---|---|---|
| B1 | §2 scope, §5.1, §5.2, §27, §28 | Remove the React web app and Node.js build from Release 1's backend scope. The gateway serves a static landing page at `/` instead of the SPA, and the `gateway.yml` pipeline does not run `npm`. | D-01, D-29 |
| B2 | §6 environment | Add the per-project `.env.example` files and the variables added during implementation: `APP_ROOT_PATH`, `GOAL_SERVICE_UPSTREAM`, `TXN_SERVICE_UPSTREAM`, `GATEWAY_RESOLVER`, `BACKUP_DIR`, `BACKUP_RETENTION_DAYS`, `KALASH_IMAGE_PREFIX` and `KALASH_IMAGE_TAG`. | D-07, plan Section 6 |
| B3 | §9.3, §11 database access | State the rule as built: runtime access only through Spring Data JPA (derived queries or JPQL) and the SQLAlchemy ORM. SQL appears only in Flyway scripts; Alembic uses the `op` API. CI searches for native SQL. | D-08 |
| B4 | §13.2, §17.3 transaction deletes | `DELETE /api/v1/transactions/{id}` and `DELETE /api/v1/transactions/goals/{goalId}` return 204 with no body. The prose in §13 that mentions response fields for deletes should be removed. Transaction history items omit `goalBalance` and `goalStatus`. | P3 evidence |
| B5 | §18, §21.1 | Gateway-generated 404, 502 and 504 responses are Problem Details with `type: about:blank`, like the services' framework errors. A connection failure to an upstream is reported as 502, and a read timeout as 504. Upstream 4xx and 5xx bodies pass through unchanged. | P4 evidence |
| B6 | §18, §25 correlation | An incoming `X-Correlation-ID` is reused only if it matches `^[A-Za-z0-9._-]{1,128}$`; otherwise the gateway, and each service, generate a new one. The gateway clears client-supplied `Forwarded`, `X-Forwarded-Port` and `X-Forwarded-Ssl` headers and sets `X-Forwarded-For` from `$remote_addr`. | P1, P4 evidence |
| B7 | §18 gateway | Upstreams use `server ... resolve` with a shared zone, so the gateway starts before the services and follows container restarts. Read timeout 10 seconds, connect timeout 2 seconds. | P4 evidence |
| B8 | New shutdown section | On Ctrl+C or SIGTERM each process stops immediately and closes its pools and clients (`server.shutdown=immediate`, `timeout_graceful_shutdown=0`, SIGQUIT for the gateway). | D-20, [ADR-0010](adr/0010-immediate-shutdown.md) |
| B9 | §23 consistency | Commit failures after a confirmed Goal change log `remoteOutcome=confirmed`; timeouts and invalid responses that may have been applied log `remoteOutcome=unknown`. Both need manual triage and must not be retried automatically. | P3 evidence |
| B10 | §27 containers | Images: `eclipse-temurin:25.0.4.1_1-jre`, `python:3.14.10-slim`, `openresty/openresty:1.31.1.1-alpine`, `postgres:18.6`, `redis:8.8.4-alpine`. All application containers run as uid 10001. Each container receives only its own variables, not the whole `.env`. Project-level compose files exist for each service with its own dependency. | D-26, P5 evidence |
| B11 | §28 CI/CD | Add the reusable image workflow and the tag rules: the 7-character SHA always, plus `<semver>` for `vX.Y.Z` tags, which must match the project version. Push only from `main` and release tags, and only when a registry is configured. Deploy over SSH with `docker compose pull` and `up -d --no-build --wait`, after waiting for the release images. | D-27, P8 evidence |
| B12 | §29 backups | Backups are written to `BACKUP_DIR/<db>/<YYYY-MM-DD>.dump` (default `./backups`) by `make backup`, checked with `pg_restore --list`, and kept for `BACKUP_RETENTION_DAYS`. Restore checks that the dump is of the same database and runs in a single transaction. Host scheduling is documented, not automated. | D-30, P7 evidence |
| B13 | §31 open issues | Close Open Issues 3 to 7 (D-31) and 6 and 9 (A1, A6). Keep Open Issues 1 (hosting), 2 (registry) and 8 (mismatch reconciliation). Add documentation exposure policy for non-local deployments (plan Open Issue 10). | Plan Section 10 |
