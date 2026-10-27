# Project Implementation Plan
## Kalash – Savings Goal Planner (Release 1)

---

## 1. Document Control

| Item | Details |
|---|---|
| Document Title | Project Implementation Plan – Kalash Savings Goal Planner |
| Product | Kalash |
| Release | Release 1 |
| Prepared By | Kalash Delivery Team |
| Prepared For | Kalash Development, QA and DevOps teams (internal) |
| Version | 1.0 – Draft for Review |
| Date | 27 October 2026 |
| Status | Draft for Review |

### 1.1 Revision History

| Version | Date | Summary of Changes |
|---|---|---|
| 1.0 | 27 October 2026 | Initial draft, based on LLD 1.0 and the agreed implementation decisions |

---

## 2. Introduction

### 2.1 Purpose

This plan explains how the Kalash Release 1 back end will be built. It covers both the business features from the BRD and LLD and the engineering features the organisation requires: rate limiting, API documentation, health checks, logging, shutdown behaviour, repository standards, containers, testing and pipelines.

The plan sets out the work, its order, and the acceptance criteria for each phase. It contains no source code.

### 2.2 Scope

| In Scope | Out of Scope |
|---|---|
| Goal Service (Java / Spring Boot) | Kalash Web App (React). The gateway will serve the web app in a later phase |
| Transaction Service (Python / FastAPI) | Authentication and Profile Service |
| API Gateway (OpenResty, an Nginx distribution, with a Redis-backed rate limiter) | Integration and end-to-end test suites (folders are created now; suites come later) |
| Goal and Transaction databases (PostgreSQL 18), Redis | External integrations (none in Release 1) |
| Containers, Docker Compose, Makefile, scripts | Production hosting and container registry selection (Open Issues) |
| Unit tests, coverage gate, CI/CD pipelines | Dashboards and alerting |
| Repository governance documents | |

### 2.3 References

| Document | Version |
|---|---|
| Business Requirements Document (BRD) – Kalash Savings Goal Planner | 1.0 |
| High Level Design (HLD) – Kalash Savings Goal Planner | 1.1 |
| Low Level Design (LLD) – Kalash Savings Goal Planner | 1.0 |
| RFC 9457 – Problem Details for HTTP APIs | – |
| Contributor Covenant | 2.1 |
| Keep a Changelog / Semantic Versioning | 1.1.0 / 2.0.0 |

---

## 3. Decision Register

These decisions were agreed with the development team before planning. Where a decision changes or extends the LLD, the Deviation column says so. The LLD will be updated to match in its next revision.

| # | Area | Decision | Deviation from LLD |
|---|---|---|---|
| D-01 | Scope | Back end and gateway only; React web app excluded | – |
| D-02 | Repository layout | `services/` (two microservices), `gateway/`, `docs/`, `scripts/`, `tests/` at root. No source code at root | New |
| D-03 | Java build | Maven with the Maven Wrapper (`mvnw`) committed | – (confirms Open Issue 6) |
| D-04 | Python packaging | `uv` with `pyproject.toml` and `uv.lock` | **Yes**: replaces pip + `requirements.txt` |
| D-05 | Java configuration | `application.yml` plus profile files (`local`, `docker`, `test`). Values come from environment variables with safe defaults | – |
| D-06 | Python configuration | `pydantic-settings` `Settings` class reading environment variables and `.env` | – |
| D-07 | `.env` files | A root `.env.example` for the full stack, plus one `.env.example` per project for standalone runs. `.env` is never committed | Extends §6 |
| D-08 | Database access | At runtime, the database is accessed only through the ORM (Spring Data JPA, SQLAlchemy 2.x ORM). SQL is allowed only in Flyway migration scripts. Alembic migrations use the `op` API | Clarifies §9.3 and §11 |
| D-09 | Rate limiting: where | At the gateway: OpenResty with a Lua limiter backed by Redis | **Yes**: new component (Redis); Nginx becomes OpenResty |
| D-10 | Rate limiting: algorithm | Sliding-window log: one Redis sorted set per client IP, updated by one atomic Lua script. Limit is 100 requests in any rolling 60 seconds | New |
| D-11 | Rate limiting: warm-up | For the first 30 seconds after the gateway starts, requests are neither limited nor counted | New |
| D-12 | Rate limiting: Redis down | Fail open: the request is forwarded and an ERROR is logged | New |
| D-13 | Rate limiting: which routes | `/api/v1/*` only. Health, readiness, docs and the landing page are not limited | New |
| D-14 | Rate limiting: response | HTTP 429 with a Problem Details body and new error code `COMMON-429`, plus `Retry-After`, `X-RateLimit-Limit`, `X-RateLimit-Remaining` and `X-RateLimit-Reset` headers | **Yes**: new error code |
| D-15 | Client IP | `$remote_addr`. The `real_ip` module trusts forwarded headers only from configured trusted proxies | New |
| D-16 | Health and readiness | Both services expose `/health` (liveness: is the process alive?) and `/ready` (readiness: are its dependencies reachable?). In Java these map onto Actuator health groups | **Yes**: adds `/health` and `/ready` |
| D-17 | Readiness dependencies | Goal Service: `goal_db`. Transaction Service: `transaction_db` only. A Goal Service outage is handled per request (503 or 504) | – |
| D-18 | OpenAPI / Swagger | springdoc (Goal Service) and FastAPI's built-in docs (Transaction Service). The gateway exposes them at `/docs/goals/` and `/docs/transactions/` (not rate limited); they are also reachable on the direct ports | **Yes**: docs routed through the gateway |
| D-19 | CORS | Disabled everywhere: no CORS middleware or headers. All callers go through the gateway's single origin | – |
| D-20 | Shutdown | On Ctrl+C or SIGTERM, stop immediately and clean up: close connection pools and HTTP clients, roll back open local transactions, and log the shutdown | New |
| D-21 | Startup banner | Coloured console summary when a service starts (Section 7.4) | New |
| D-22 | Log format | Structured JSON in the `docker` profile; coloured human-readable logs in the `local` profile | Extends §25 |
| D-23 | Testing | Unit tests only: JUnit 5 + Mockito, pytest, and busted (Lua). Coverage is measured with JaCoCo and pytest-cov, and the build fails below 80% line coverage | **Yes**: integration tests (Testcontainers) deferred |
| D-24 | Documentation comments | Javadoc, Google-style docstrings and LuaDoc on all major business code. Enforced by the CONTRIBUTING guide and code review, not by the build | New |
| D-25 | Make | Root and per-project Makefiles. Each target calls a matching pair of scripts in `scripts/` (`.sh` for Bash and `.ps1` for PowerShell) | New |
| D-26 | Docker Compose | A root compose file runs the full stack. Each project's compose file runs the service and its own dependencies | Extends §27 |
| D-27 | CI/CD | GitHub Actions per LLD §28: lint, test, coverage, build, image push and deploy. The registry is a placeholder until Open Issue 2 is resolved | – |
| D-28 | Governance | MIT License (© 2026 Kalash Financial Services), Contributor Covenant 2.1, Keep a Changelog, Semantic Versioning | New |
| D-29 | Gateway `/` | A small static landing page listing the API base paths, documentation links, and health and readiness links | New |
| D-30 | Backups | Backup and restore scripts per LLD §29 (`.sh` and `.ps1`) with Make targets. Host scheduling is documented, not automated | – |
| D-31 | LLD Open Issues 3–7 | Adopted: name maximum 100 characters, history newest first, page size 20 (maximum 100), the LLD tooling proposals (pip replaced by D-04), 7-day backup retention | Closes Open Issues 3–7 |

---

## 4. Target Repository Structure

```
kalash/
├── README.md                     # Complete project guide (Section 5.10)
├── LICENSE                       # MIT, © 2026 Kalash Financial Services
├── CODE_OF_CONDUCT.md            # Contributor Covenant 2.1
├── CONTRIBUTING.md               # Branching, commits, code standards, doc comments, PR checklist
├── SECURITY.md                   # Supported versions, how to report, Release 1 limitations
├── TROUBLESHOOTING.md            # Common problems and fixes
├── CHANGELOG.md                  # Keep a Changelog format
├── Makefile                      # Root targets that call project Makefiles and scripts
├── docker-compose.yml            # Full stack
├── .env.example                  # Full-stack variables (no secrets)
├── .gitignore
├── .editorconfig
├── .gitattributes                # Line endings (LF for .sh, CRLF allowed for .ps1)
├── .github/
│   ├── workflows/                # goal-service.yml, transaction-service.yml, gateway.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── ISSUE_TEMPLATE/
├── docs/                         # BRD, HLD, LLD, implementation plans, diagrams
│   └── adr/                      # Architecture decision records (D-xx)
├── scripts/                      # Matching .sh and .ps1 scripts (Section 5.8)
│   ├── setup.sh / setup.ps1
│   ├── lint.sh / lint.ps1
│   ├── test.sh / test.ps1
│   ├── backup.sh / backup.ps1
│   ├── restore.sh / restore.ps1
│   └── ...
├── tests/                        # Placeholders for future suites
│   ├── integration/README.md
│   └── e2e/README.md
├── services/
│   ├── goal-service/
│   │   ├── README.md
│   │   ├── Makefile
│   │   ├── Dockerfile
│   │   ├── .dockerignore
│   │   ├── docker-compose.yml    # goal-service + goal-db
│   │   ├── .env.example
│   │   ├── mvnw, mvnw.cmd, .mvn/
│   │   ├── pom.xml
│   │   └── src/
│   │       ├── main/java/com/kalash/goal/
│   │       │   ├── GoalServiceApplication.java
│   │       │   ├── goal/         # api/, service/, domain/, repository/
│   │       │   ├── balance/      # api/, service/ (BalanceAdjustmentService, StatusEvaluator)
│   │       │   ├── insights/     # InsightsCalculator, Insights
│   │       │   └── common/
│   │       │       ├── error/    # ErrorCode, ApiException, GlobalExceptionHandler
│   │       │       ├── config/   # Clock, Jackson, OpenAPI, Actuator health groups
│   │       │       ├── logging/  # CorrelationIdFilter, log profiles
│   │       │       └── lifecycle/# StartupBanner, ShutdownListener
│   │       ├── main/resources/
│   │       │   ├── application.yml
│   │       │   ├── application-local.yml
│   │       │   ├── application-docker.yml
│   │       │   ├── banner.txt
│   │       │   ├── logback-spring.xml
│   │       │   └── db/migration/ # V1__create_goals.sql
│   │       └── test/java/com/kalash/goal/   # Same package structure as main
│   └── transaction-service/
│       ├── README.md
│       ├── Makefile
│       ├── Dockerfile
│       ├── .dockerignore
│       ├── docker-compose.yml    # transaction-service + transaction-db
│       ├── .env.example
│       ├── pyproject.toml        # Dependencies plus Ruff, pytest and coverage settings
│       ├── uv.lock
│       ├── alembic.ini
│       ├── alembic/versions/     # 0001_create_transactions.py
│       ├── app/
│       │   ├── main.py           # App factory, lifespan, banner, signal handling
│       │   ├── transactions/     # router, schemas, service, models, repository
│       │   ├── goal_deletion/    # router, service
│       │   ├── clients/          # goal_client.py (httpx)
│       │   ├── health/           # /health, /ready
│       │   └── common/           # config, db, errors, logging, clock, banner
│       └── tests/unit/           # Same structure as app/
└── gateway/
    ├── README.md
    ├── Makefile
    ├── Dockerfile                # Based on OpenResty
    ├── .dockerignore
    ├── docker-compose.yml        # gateway + redis
    ├── .env.example
    ├── conf/
    │   ├── nginx.conf
    │   └── conf.d/               # upstreams, routes, docs, logging, real_ip
    ├── lua/kalash/
    │   ├── ratelimit.lua         # Sliding-window log limiter
    │   ├── ratelimit_script.lua  # Atomic Redis script
    │   ├── problem.lua           # Problem Details builder
    │   └── warmup.lua            # Start-time capture and warm-up check
    ├── html/index.html           # Landing page
    └── spec/                     # busted unit tests
```

**Structure rules**
- The root holds only documentation, orchestration and repository configuration. No source code lives at the root.
- Each project builds, tests and runs on its own (its own Makefile, compose file, `.env.example` and README).
- Feature-based packages and dependency rules follow LLD §7.3. Controllers and routers contain no business logic.
- Unit tests mirror the package structure of the code they test.

---

## 5. Phased Implementation Plan

| Phase | Name | Depends On |
|---|---|---|
| P0 | Repository foundation and governance | – |
| P1 | Cross-cutting foundations (both services) | P0 |
| P2 | Goal Service: business features | P1 |
| P3 | Transaction Service: business features | P1, P2 (internal API contract) |
| P4 | API Gateway and rate limiter | P0 |
| P5 | Containers and Docker Compose | P2, P3, P4 |
| P6 | Unit tests and quality gates | Runs alongside P2–P4 |
| P7 | Makefile and scripts | Starts in P0; completed in P5 |
| P8 | CI/CD pipelines | P5, P6 |
| P9 | Documentation and handoff | All |

P4 can run in parallel with P2 and P3.

### 5.1 P0 – Repository Foundation and Governance

**Tasks**
- [ ] Create the folder layout from Section 4, with empty `tests/integration` and `tests/e2e` folders that each have a README.
- [ ] Add `.gitignore` covering Java (`target/`), Python (`.venv/`, `__pycache__/`, `.pytest_cache/`, `.ruff_cache/`, `htmlcov/`, `.coverage`), Lua, IDE files, OS files, `.env` and `*.dump`.
- [ ] Add `.editorconfig` and `.gitattributes` (shell scripts use LF line endings).
- [ ] Add `LICENSE`: MIT, "Copyright (c) 2026 Kalash Financial Services".
- [ ] Add `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1, with a Kalash contact address).
- [ ] Add `CONTRIBUTING.md`: branching, commit conventions, coding standards (LLD §8), documentation-comment rules (Section 7.8), test and coverage rules, PR checklist.
- [ ] Add `SECURITY.md`: how to report issues, supported versions, Release 1 limitations (demo login, no back-end authentication).
- [ ] Add `TROUBLESHOOTING.md` with initial entries (ports in use, Docker not running, `make` on Windows, migration failures, Redis down, 429 responses).
- [ ] Add `CHANGELOG.md` with an `Unreleased` section and the planned `1.0.0` entry.
- [ ] Add a skeleton root `README.md`, completed in P9.
- [ ] Add a root `.env.example` with all full-stack variables (Section 6).
- [ ] Add the PR template and issue templates.

**Acceptance criteria**
- The root contains no source code files.
- Every governance file listed above exists and is linked from the README.

### 5.2 P1 – Cross-cutting Foundations (Both Services)

**Tasks: Goal Service**
- [x] Bootstrap Spring Boot 4.1 / Java 25 with Maven Wrapper, Spotless, JaCoCo (80% gate), springdoc-openapi, Actuator and Micrometer Prometheus.
- [x] Add `application.yml` with environment placeholders; add `local`, `docker` and `test` profiles.
- [x] Add a `Clock` bean fixed to the `APP_TIMEZONE` setting (Asia/Kolkata).
- [x] Add the error framework: `ErrorCode` enum (full LLD §21.2 catalogue plus `COMMON-429` for documentation), `ApiException`, and a `GlobalExceptionHandler` that returns `ProblemDetail` with `errorCode`, `correlationId`, `timestamp` and `errors[]`.
- [x] Map database constraint violations to the matching codes (for example, the unique-name index to `GOAL-002`).
- [x] Add `CorrelationIdFilter`: reads or creates `X-Correlation-ID`, stores it in MDC and echoes it on the response.
- [x] Logging: ECS JSON in the `docker` profile; coloured console pattern in `local`.
- [x] Health: Actuator liveness and readiness groups, with `additional-path` mapping `/health` and `/ready` on the server port. Readiness includes the DB check.
- [x] OpenAPI: `/v3/api-docs` and `/swagger-ui`, with the server URL set so docs work behind `/docs/goals/`. Internal endpoints are tagged "Internal".
- [x] CORS: none configured; no `@CrossOrigin` anywhere.
- [x] Startup banner (Section 7.4) via `banner.txt` and an `ApplicationReadyEvent` listener.
- [x] Shutdown: `server.shutdown=immediate`. A listener on `ContextClosedEvent` logs shutdown; Spring closes Hikari and the JVM shutdown hook handles Ctrl+C.

**Tasks: Transaction Service**
- [x] Bootstrap with `uv`: FastAPI 0.136, Pydantic 2, SQLAlchemy 2, Alembic, psycopg 3, httpx, pydantic-settings, prometheus-fastapi-instrumentator and `rich` (for the banner). Dev tools: Ruff, pytest, pytest-cov, respx, pytest-asyncio as needed.
- [x] Add a `Settings` class (`.env` plus environment variables), validated at startup.
- [x] Add a clock abstraction (Asia/Kolkata) that can be injected and fixed in tests.
- [x] Add the error framework: an `ApiError` hierarchy and exception handlers returning `application/problem+json`. Pydantic validation errors map to `COMMON-400` with `errors[]`.
- [x] Add correlation middleware: a `contextvar` that is forwarded on httpx calls and echoed on responses.
- [x] Logging: JSON formatter in the `docker` profile; coloured console (`rich` handler) in `local`.
- [x] Health: `/health` (process alive) and `/ready` (an ORM session connectivity check on `transaction_db`, without hand-written SQL).
- [x] OpenAPI: `/openapi.json` and `/docs`, with `root_path` and server settings so docs work behind `/docs/transactions/`.
- [x] CORS: no `CORSMiddleware`.
- [x] Lifespan: on startup, create the engine, session factory and httpx client, then print the banner. On shutdown, dispose of the engine, close httpx and log shutdown.
- [x] Shutdown: Uvicorn's SIGINT/SIGTERM handling with `timeout_graceful_shutdown=0`, so the process exits immediately; open sessions are rolled back on cancellation.

**Acceptance criteria**
- Both services start locally with coloured banners and stop cleanly on Ctrl+C. The log shows every resource closed.
- `/health`, `/ready` and the Swagger UI respond on the direct ports.
- No CORS headers are returned for a request that includes an `Origin` header.

**P1 execution evidence**
- Goal Service: Spring Boot 4.1.2, Java 25.0.1, springdoc 3.2.0 and Boot-managed Jupiter 6.0.3. Maven Wrapper `verify` passed with 55 tests and 96.49% line coverage, including an offline Docker run with networking disabled.
- Transaction Service: FastAPI 0.136.3 on Python 3.14.2. Locked Ruff checks and pytest passed with 73 tests and 99.73% line coverage. One upstream Starlette/AnyIO deprecation warning remains.
- Real-process PostgreSQL 18 checks passed for direct health/readiness/docs/metrics, DB outage behavior, correlation IDs, no CORS, safe startup output and signal-driven resource cleanup. Temporary test processes and containers were removed.
- Java 25 validation used Docker without replacing the host JDK. Python uses a service-local virtual environment. Run instructions are in the service READMEs.
- `APP_ROOT_PATH` makes FastAPI's documentation prefix configurable; OpenAPI's API server stays at `/`. Framework routing errors retain their HTTP status with `about:blank` instead of inventing domain error codes.
- Business endpoints, schemas/migrations, gateway implementation and committed integration/e2e suites remain deferred.

### 5.3 P2 – Goal Service: Business Features

| Task | Details | Stories / Rules |
|---|---|---|
| [ ] Flyway `V1__create_goals.sql` | Table, CHECK constraints, `ux_goals_name_ci`, `ix_goals_target_date` (LLD §9.1) | BR-03, 04, 14, 25 |
| [ ] `Goal` entity and `GoalStatus` enum | JPA mapping, `@Version`, UTC timestamps | – |
| [ ] `GoalRepository` | Spring Data JPA: derived queries for the case-insensitive name check and the sorted, paginated overview. No hand-written SQL strings | BR-03, 25 |
| [ ] Request and response DTOs | `CreateGoalRequest`, `UpdateGoalRequest` (at least one field), `GoalResponse`, `PageResponse`; float-to-integer coercion disabled | BR-02, 04 |
| [ ] `GoalRules` | `ensureNameUnique`, `ensureFutureDate`, `ensureTargetAboveBalance`, `ensureEditAllowed` | BR-03, 05, 06, 17, 19 |
| [ ] `GoalService` | create, get, list, update, cancel | KAL-BUC-00001, 00002, 00003, 00014 |
| [ ] `StatusEvaluator` | Active ↔ Achieved transitions (LLD §15) | KAL-BUC-00015, 00016; BR-15, 16 |
| [ ] `InsightsCalculator` | Pure function with an injected clock (LLD §16) | KAL-BUC-00010 to 00013; BR-21 to 24 |
| [ ] `BalanceAdjustmentService` | Operation and status check, non-negative balance, then status evaluation. Retries up to 3 times on an optimistic-lock conflict, then returns `COMMON-409` | BR-10, 12, 13, 14 |
| [ ] `GoalController` (public) | The 5 endpoints in LLD §13.1; `201` responses carry a `Location` header | – |
| [ ] `BalanceAdjustmentController` (internal) | The 3 endpoints in LLD §14 under `/internal/v1/goals` | KAL-BUC-00004 to 00008 |
| [ ] Documentation comments | Javadoc on every public class and method in `goal`, `balance` and `insights` | D-24 |

**Acceptance criteria**
- Every endpoint matches the LLD contract and returns Problem Details with the catalogued codes.
- All seven worked examples in LLD §16.4 pass as unit tests.
- No runtime SQL strings exist (`@Query` with native SQL is not allowed).

### 5.4 P3 – Transaction Service: Business Features

| Task | Details | Stories / Rules |
|---|---|---|
| [ ] Alembic `0001_create_transactions` | `op` API only: table, CHECK constraints, `ix_transactions_goal_created` (LLD §9.2) | BR-07 |
| [ ] `models.py` | SQLAlchemy 2 declarative model; `version_id_col` | – |
| [ ] `repository.py` | ORM `select()`, `session.add()` and `session.delete()` only; paginated history, newest first | KAL-BUC-00009 |
| [ ] `schemas.py` | Pydantic models with `StrictInt` and `gt=0`; `type` as an enum; page and size limits | BR-07 |
| [ ] `GoalClient` | httpx client: 3-second timeout, no retries, forwards the correlation ID. Maps responses: 4xx passed through, timeout to `TXN-003`, connection failure or 5xx to `TXN-002` | LLD §14 |
| [ ] `transactions/service.py` | Create (deposit or withdrawal), edit (delta calculation), delete (reverse delta). Each one: local change without commit → Goal Service call → commit, or roll back | KAL-BUC-00005 to 00008; BR-09, 10 to 14 |
| [ ] Transaction date | Set from the IST clock and never updated | BR-09 |
| [ ] Mismatch logging | If the Goal Service applied a change but the local commit failed, log at ERROR with correlation ID, goal ID and delta | LLD §23 |
| [ ] `goal_deletion/service.py` | Read goal snapshot → confirm Cancelled → delete history and commit → call the internal delete; safe to repeat (LLD §17.3) | KAL-BUC-00004; BR-20 |
| [ ] Routers | The 5 endpoints in LLD §13.2; routers only delegate to services | – |
| [ ] Documentation comments | Google-style docstrings on every public module, class and function in `transactions`, `goal_deletion` and `clients` | D-24 |

**Acceptance criteria**
- Every failure path in LLD §14 and §23 rolls back the local change, and a unit test proves it.
- Goal Service Problem Details are passed through unchanged.
- No raw SQL (`text()`, `exec_driver_sql`) is used in application code.

### 5.5 P4 – API Gateway and Rate Limiter

**Tasks**
- [ ] OpenResty base image, `nginx.conf` and `conf.d/` split into upstreams, routes, docs, logging and real_ip.
- [ ] Routing per LLD §18: `/api/v1/goals` and `/api/v1/transactions` (10-second read timeout); `/internal/` returns 404; correlation ID mapped and added to every response.
- [ ] Docs routes: `/docs/goals/` (Swagger UI and `/v3/api-docs`) and `/docs/transactions/` (`/docs` and `/openapi.json`), not rate limited.
- [ ] Health routes: `/health` (gateway liveness), `/ready` (gateway can reach Redis; reported as degraded, not failed, because the limiter fails open), plus pass-through routes `/health/goals`, `/ready/goals`, `/health/transactions` and `/ready/transactions`.
- [ ] Metrics endpoints are not routed (LLD §26).
- [ ] Landing page `/` (static HTML): API base paths, docs links, health links and version.
- [ ] `real_ip`: `set_real_ip_from` uses the trusted proxy list from the environment (empty by default); the rate-limit key is `$remote_addr`.
- [ ] Warm-up: `init_worker_by_lua` records the gateway start time in a shared dictionary. For the first 30 seconds (`RATE_LIMIT_WARMUP_SECONDS`), requests skip the limiter and are not counted.
- [ ] Limiter, in `access_by_lua` for `/api/v1/*` only: one atomic Redis script removes entries older than 60 seconds, counts the rest, then either adds the request (if the count is under 100) or rejects it. The script returns remaining capacity and reset time. The key has a 60-second expiry and each entry gets a unique member ID.
- [ ] Rejection: HTTP 429 with Problem Details (`COMMON-429`, "Too many requests, please retry later") and the `Retry-After` and `X-RateLimit-*` headers. Allowed responses also carry the `X-RateLimit-*` headers.
- [ ] Fail open: any Redis error or timeout (short connect and read timeouts, connection pooling) forwards the request and logs ERROR with `event=ratelimit_store_unavailable`.
- [ ] JSON access log including `$correlation_id`, the client IP and the rate-limit outcome.
- [ ] Limits come from environment variables: `RATE_LIMIT_REQUESTS=100`, `RATE_LIMIT_WINDOW_SECONDS=60`, `RATE_LIMIT_WARMUP_SECONDS=30`.
- [ ] Gateway console start-up banner: listening port, upstreams, limiter settings, Redis target.
- [ ] LuaDoc comments on all Lua modules.

**Acceptance criteria**
- During warm-up, request 101 inside 60 seconds is allowed. After warm-up, request 101 returns 429 with the correct headers.
- Health, readiness and docs routes are never limited.
- With Redis stopped, API requests still succeed and an ERROR is logged.
- `/internal/*` returns 404 through the gateway.

### 5.6 P5 – Containers and Docker Compose

**Tasks**
- [ ] `services/goal-service/Dockerfile`: multi-stage (Maven build, then `eclipse-temurin:25-jre`), non-root user, a `HEALTHCHECK` on `/health`, JVM memory settings for containers.
- [ ] `services/transaction-service/Dockerfile`: multi-stage (`uv sync --frozen`, then `python:3.14-slim`), non-root user. The entrypoint runs `alembic upgrade head` and then Uvicorn, with `exec` so signals reach Uvicorn.
- [ ] `gateway/Dockerfile`: OpenResty (Alpine), copies `conf/`, `lua/` and `html/`.
- [ ] `.dockerignore` in every project (build output, virtual environments, caches, tests, `.env`, `.git`).
- [ ] Root `docker-compose.yml`: gateway, goal-service, transaction-service, goal-db, transaction-db, redis. Includes health checks, `depends_on: condition: service_healthy` (dependencies wait for `/ready`), `restart: unless-stopped`, named volumes, one internal network, host ports per LLD §5.1, and Redis not published.
- [ ] Project compose files: goal-service + goal-db; transaction-service + transaction-db (with `GOAL_SERVICE_BASE_URL` configurable); gateway + redis (upstream addresses configurable).
- [ ] Use a `stop_grace_period` short enough to match the immediate-shutdown decision (D-20).
- [ ] Image labels: version, git SHA, licence.

**Acceptance criteria**
- `make up` starts the full stack and every container becomes healthy.
- Each project-level compose file starts on its own.
- `docker compose down` stops every container cleanly.

### 5.7 P6 – Unit Tests and Quality Gates

| Project | Framework | Test Doubles | Coverage Gate |
|---|---|---|---|
| Goal Service | JUnit 5 (Jupiter API), Mockito, AssertJ, `@WebMvcTest` slices | Mocked repositories, fixed `Clock` | JaCoCo, 80% line coverage |
| Transaction Service | pytest, FastAPI `TestClient`, respx | Mocked repository and session, respx for the Goal Service, fixed clock | pytest-cov, `--cov-fail-under=80` |
| Gateway | busted, luacheck | Fake Redis client, fake clock, fake `ngx` object | luacov report (no gate) |

**Test matrix (minimum)**

| Unit | Must Cover |
|---|---|
| `InsightsCalculator` | All 7 LLD §16.4 cases, all §16.5 edge rules, Cancelled returns null, rounding |
| `StatusEvaluator` | Active → Achieved at `balance == target` and `balance > target`; Achieved → Active on withdrawal and on target raise |
| `GoalRules` | BR-03 (case and whitespace variants), BR-05 (today, tomorrow, past dates in IST), BR-06, BR-17, BR-19 |
| `GoalService` | Create, update (partial), cancel (`GOAL-006`, `GOAL-007`), not found (`GOAL-001`), overview sorting and paging |
| `BalanceAdjustmentService` | Each operation × each status (LLD §14 table), `GOAL-009` to `GOAL-012`, optimistic-lock retry ×3 then `COMMON-409` |
| Goal controllers | Status codes, `Location` header, Problem Details shape, validation (`COMMON-400` with `errors[]`), decimals rejected |
| Transaction service | Deposit and withdrawal flow, edit delta (both types), delete reverse delta, transaction date from the clock, commit only on Goal Service success |
| `GoalClient` | 4xx pass-through, timeout to `TXN-003`, connection refused or 5xx to `TXN-002`, correlation header forwarded |
| Goal deletion | Not found, not Cancelled (`GOAL-008`), success, retry after partial failure |
| Transaction routers | Validation (`StrictInt`, `gt=0`, enum), pagination limits, `TXN-001`, Problem Details content type |
| Health and readiness | Both services: `/health` always up; `/ready` down when the database check fails |
| Lua limiter | Under limit, exactly at 100, request 101 gets 429, window sliding at 60 seconds, warm-up bypass and no counting, end of warm-up, Redis error fails open, headers, non-`/api` paths skipped |

**Rules**
- Every error code in LLD §21.2, plus `COMMON-429`, has at least one test.
- Time-dependent tests use a fixed clock. No test depends on the real date or time.
- Unit tests start no database, Redis or network.
- Lint and format checks: Spotless (Java), Ruff check and format (Python), luacheck (Lua).

### 5.8 P7 – Makefile and Scripts

Root `Makefile` targets call the project Makefiles. Each recipe chooses `scripts/<name>.sh` or `scripts/<name>.ps1` based on the operating system.

| Target | Purpose |
|---|---|
| `help` | List all targets (default) |
| `setup` | Check required tools (Java 25, uv, Docker, make) and copy each `.env.example` to `.env` if it is missing |
| `format` / `lint` | Spotless and Ruff format; Spotless check, Ruff check and luacheck |
| `test` / `test-goal` / `test-txn` / `test-gateway` | Unit tests (all projects or one) |
| `coverage` | Run tests with coverage reports and enforce the gate |
| `build` | Build all images |
| `up` / `down` / `restart` | Full-stack compose lifecycle |
| `logs` / `ps` | Follow logs; show container status |
| `run-goal` / `run-txn` | Run one service on the host with the `local` profile (coloured logs) |
| `migrate` | Apply Alembic migrations (Flyway runs when the Goal Service starts) |
| `backup` / `restore DB=<db> FILE=<file>` | LLD §29 backup and restore |
| `clean` | Remove build output, caches and coverage reports |

**Scripts:** `setup`, `lint`, `format`, `test`, `coverage`, `backup`, `restore`, `clean`, `wait-for-ready`. Each exists as both `.sh` and `.ps1`, starts with a usage comment, and fails fast on errors.

### 5.9 P8 – CI/CD Pipelines (GitHub Actions)

| Workflow | Trigger (path filter) | Steps |
|---|---|---|
| `goal-service.yml` | `services/goal-service/**` | Checkout → JDK 25 → Spotless check → `mvnw verify` (unit tests + JaCoCo gate) → upload coverage → Docker build → push (`main` and tags) |
| `transaction-service.yml` | `services/transaction-service/**` | Checkout → uv → Ruff → pytest with coverage gate → upload coverage → Docker build → push (`main` and tags) |
| `gateway.yml` | `gateway/**` | Checkout → luacheck → busted → `nginx -t` config test in the image → Docker build → push (`main` and tags) |
| `deploy.yml` | Manual or release tag | `docker compose pull && docker compose up -d` on the target host (host is an Open Issue) |

- Image tags are `<semver>` and `<git-sha>`. The registry and its credentials are GitHub secrets and placeholders until Open Issue 2 is resolved.
- PRs require all three pipelines to pass for any project they change.

### 5.10 P9 – Documentation and Handoff

**Root README.md sections**
1. Overview: product, Release 1 scope, architecture diagram (Mermaid)
2. Repository structure
3. Technology stack and versions
4. Prerequisites (Windows, macOS and Linux, including how to install `make` on Windows)
5. Quick start: `make setup`, `make up`, URLs
6. Configuration: every environment variable (Section 6)
7. Services: ports, API base paths, Swagger, health, readiness
8. API summary (public endpoints) and error-code catalogue link
9. Rate limiting behaviour (limit, warm-up, 429 response, headers, fail-open)
10. Logging and correlation IDs; startup banner; shutdown behaviour
11. Testing: how to run tests, the coverage gate, future integration and e2e folders
12. Make targets and scripts
13. Docker and Compose (root and project level)
14. CI/CD
15. Backup and restore
16. Security notes and Release 1 limitations
17. Links to Contributing, Code of Conduct, Security, Troubleshooting, Changelog, License; docs index

**Also**
- [ ] A README per project (purpose, standalone run, configuration, tests).
- [ ] Architecture decision records in `docs/adr/` for D-04, D-09 to D-14, D-16, D-18 and D-20.
- [ ] The `1.0.0` entry in `CHANGELOG.md`.
- [ ] A list of the LLD updates needed by the deviations (D-04, D-09, D-14, D-16, D-18, D-23).

---

## 6. Configuration Matrix

| Variable | Used By | Default / Example |
|---|---|---|
| `APP_ENV` / `SPRING_PROFILES_ACTIVE` | Services | `local` / `docker` |
| `APP_ROOT_PATH` | Transaction Service documentation | empty for direct access; `/docs/transactions` for a prefix-stripping documentation proxy |
| `APP_TIMEZONE` | Goal, Transaction | `Asia/Kolkata` |
| `LOG_LEVEL` | All | `INFO` |
| `GOAL_SERVICE_PORT` / `TXN_SERVICE_PORT` | Services | `8080` / `8000` |
| `GOAL_DB_HOST` / `GOAL_DB_PORT` / `GOAL_DB_NAME` / `GOAL_DB_USER` / `GOAL_DB_PASSWORD` | Goal Service, goal-db | `goal-db` / `5432` / `goal_db` / `goal_user` / `***` |
| `TXN_DB_HOST` / `TXN_DB_PORT` / `TXN_DB_NAME` / `TXN_DB_USER` / `TXN_DB_PASSWORD` | Transaction Service, transaction-db | `transaction-db` / `5432` / `transaction_db` / `txn_user` / `***` |
| `GOAL_SERVICE_BASE_URL` | Transaction Service | `http://goal-service:8080` |
| `GOAL_SERVICE_TIMEOUT_SECONDS` | Transaction Service | `3` |
| `REDIS_HOST` / `REDIS_PORT` / `REDIS_TIMEOUT_MS` | Gateway | `redis` / `6379` / `100` |
| `RATE_LIMIT_REQUESTS` / `RATE_LIMIT_WINDOW_SECONDS` / `RATE_LIMIT_WARMUP_SECONDS` | Gateway | `100` / `60` / `30` |
| `TRUSTED_PROXIES` | Gateway | empty |
| `BACKUP_DIR` / `BACKUP_RETENTION_DAYS` | Scripts | `./backups` / `7` |

Passwords are only ever in `.env` and never in code, logs or the startup banner.

---

## 7. Cross-cutting Design Details

### 7.1 Error Code Addition

| Code | HTTP | Title | Raised By |
|---|---|---|---|
| COMMON-429 | 429 | Too many requests, please retry later | Gateway rate limiter |

### 7.2 Health and Readiness

| Endpoint | Goal Service | Transaction Service | Gateway |
|---|---|---|---|
| `/health` | Process alive (Actuator liveness group) | Process alive | Nginx responding |
| `/ready` | Includes `goal_db` (Actuator readiness group with the DB indicator) | Includes an ORM connectivity check on `transaction_db` | Redis reachable (degraded only; the limiter fails open) |

### 7.3 API Documentation

| Service | Direct | Through the Gateway |
|---|---|---|
| Goal Service | `:8080/swagger-ui`, `:8080/v3/api-docs` | `/docs/goals/` |
| Transaction Service | `:8000/docs`, `:8000/openapi.json` | `/docs/transactions/` |

Every operation, schema and error response is documented with examples. Internal endpoints are documented under a separate "Internal" tag.

### 7.4 Startup Banner (Coloured Console)

| Group | Items |
|---|---|
| Identity | Service name, application version, active profile, Java or Python version |
| Network | Port, API base URL, Swagger URL, OpenAPI URL, `/health`, `/ready`, metrics URL |
| Dependencies | Database host, port and name; Goal Service URL (Transaction Service). Never passwords or secrets |
| Settings | Timezone, log level, PID, startup duration |

Colour is used only when the console supports it (a TTY and `NO_COLOR` not set). Otherwise the banner is plain text, so container logs stay clean.

### 7.5 Shutdown (Ctrl+C / SIGTERM)

| Service | Behaviour |
|---|---|
| Goal Service | `server.shutdown=immediate`. The JVM shutdown hook closes the context, the Hikari pool and executors. The shutdown is logged |
| Transaction Service | Uvicorn stops immediately. Lifespan shutdown disposes of the SQLAlchemy engine and closes the httpx client. Interrupted requests roll back their sessions. The shutdown is logged |
| Gateway | `nginx -s quit` (the container stop signal); Redis connections are released |

### 7.6 Logging

LLD §25 applies (fields, levels, correlation ID). This plan adds the rate-limiter events (`ratelimit_rejected` at WARN, `ratelimit_store_unavailable` at ERROR), startup, shutdown and resource-closed events at INFO, and profile-based output formats (D-22).

### 7.7 ORM-only Data Access

| Allowed | Not Allowed |
|---|---|
| Spring Data JPA repositories, derived queries, JPQL (if needed) | Native SQL queries, `JdbcTemplate`, string-built queries |
| SQLAlchemy ORM `select()`, `session.add()`, `session.delete()` | `text()`, `exec_driver_sql`, raw cursors |
| Flyway `.sql` migrations; Alembic `op` API | SQL inside application code |

These rules are checked in code review and by a CI step that searches application code (migrations excluded) for the banned patterns.

### 7.8 Documentation Comments

| Language | Standard | Required On |
|---|---|---|
| Java | Javadoc (`@param`, `@return`, `@throws`) | Public classes and methods in `goal`, `balance`, `insights` and `common.error` |
| Python | Google-style docstrings | Public modules, classes and functions in `transactions`, `goal_deletion`, `clients` and `common` |
| Lua | LuaDoc | Every module and public function in `lua/kalash` |

Each comment states the business rule it implements (for example "Implements BR-12, BR-14").

---

## 8. Traceability Matrix

| Story | Rules | Implemented In | Unit Tests |
|---|---|---|---|
| KAL-BUC-00001 Create Goal | BR-01 to 05 | `GoalService.create`, `GoalRules` | `GoalServiceTest`, `GoalRulesTest`, `GoalControllerTest` |
| KAL-BUC-00002 Edit Goal | BR-05, 06, 16, 17, 19 | `GoalService.update`, `GoalRules`, `StatusEvaluator` | `GoalServiceTest`, `GoalRulesTest` |
| KAL-BUC-00003 Cancel Goal | BR-18 | `GoalService.cancel` | `GoalServiceTest` |
| KAL-BUC-00004 Delete Cancelled Goal | BR-20 | `goal_deletion.service`, internal DELETE | `test_goal_deletion_service`, `BalanceAdjustmentControllerTest` |
| KAL-BUC-00005 Record Deposit | BR-07 to 11, 15 | `transactions.service`, `BalanceAdjustmentService` | `test_transaction_service`, `BalanceAdjustmentServiceTest` |
| KAL-BUC-00006 Record Withdrawal | BR-07, 09, 12, 14, 16 | Same as above | Same as above |
| KAL-BUC-00007 Edit Transaction | BR-07, 13, 14 | `transactions.service` (delta), `BalanceAdjustmentService` | `test_transaction_service`, `BalanceAdjustmentServiceTest` |
| KAL-BUC-00008 Delete Transaction | BR-13, 14 | Same as above | Same as above |
| KAL-BUC-00009 Transaction History | – | `transactions.repository`, router | `test_transaction_router` |
| KAL-BUC-00010 Goal Progress | BR-22 | `InsightsCalculator` | `InsightsCalculatorTest` |
| KAL-BUC-00011 Suggested Monthly Saving | BR-23 | `InsightsCalculator` | `InsightsCalculatorTest` |
| KAL-BUC-00012 Off-track | BR-24 | `InsightsCalculator` | `InsightsCalculatorTest` |
| KAL-BUC-00013 Overdue | BR-21 | `InsightsCalculator` | `InsightsCalculatorTest` |
| KAL-BUC-00014 Overview | BR-25 | `GoalService.list`, `GoalRepository` | `GoalServiceTest` |
| KAL-BUC-00015 Auto-achieve | BR-15 | `StatusEvaluator` | `StatusEvaluatorTest` |
| KAL-BUC-00016 Return to Active | BR-16 | `StatusEvaluator`, `GoalService.update` | `StatusEvaluatorTest`, `GoalServiceTest` |

**Requested engineering capabilities**

| Capability | Phase | Decision |
|---|---|---|
| Rate limiting (by IP, 30-second warm-up, 100 requests/minute) | P4 | D-09 to D-15 |
| OpenAPI and Swagger for all microservices | P1, P4 | D-18 |
| Health and readiness endpoints | P1, P4 | D-16, D-17 |
| Documentation comments | P2, P3, P4 | D-24 |
| Modular project structure | P0 to P4 | D-02, Section 4 |
| Root README, `.gitignore`, MIT License, governance files | P0, P9 | D-28 |
| `.dockerignore` per project; compose at root and project level | P5 | D-26 |
| `.env` (Python) and resource files (Java) | P1 | D-05 to D-07 |
| No source at root; `docs`, `tests`, `scripts` used properly | P0 | D-02 |
| Coloured startup information | P1, P4 | D-21 |
| Ctrl+C shutdown with resource cleanup | P1 | D-20 |
| ORM only, no direct SQL | P2, P3 | D-08 |
| Unit tests now; integration and e2e later | P6 | D-23 |
| Makefile targets | P7 | D-25 |
| CORS disabled | P1 | D-19 |

---

## 9. Risks and Mitigations

| # | Risk | Mitigation |
|---|---|---|
| R-01 | Immediate shutdown (D-20) can stop the Transaction Service after the Goal Service has applied a change but before the local commit, leaving the two databases out of step | Mismatch ERROR log with correlation ID, goal ID and delta; manual correction procedure in TROUBLESHOOTING; Open Issue 8 stays open |
| R-02 | Every gateway restart starts a new 30-second unlimited window | Accepted by design; restarts are logged and the banner shows the warm-up end time |
| R-03 | Fail-open (D-12) removes protection while Redis is down | ERROR log for every failure, gateway `/ready` reports degraded, Redis has a health check and restarts automatically |
| R-04 | Sliding-window log uses one Redis entry per request per IP | The key expires after 60 seconds; the limit caps each key at 100 entries; memory usage is documented |
| R-05 | Library support for Java 25, Spring Boot 4.1 and Python 3.14 (springdoc, Spotless, JaCoCo, psycopg) | Confirm compatibility in P1; if anything fails, raise a decision rather than change versions silently |
| R-06 | Windows developer tooling (make, shell scripts) | Matching `.ps1` scripts, installation guidance in the README and TROUBLESHOOTING, LF line endings enforced for `.sh` |
| R-07 | Unit-only testing does not prove the interaction between services, the database or Redis | Integration and e2e suites planned (`tests/` placeholders); contract shapes fixed by LLD §13 and §14 |
| R-08 | Swagger reachable through the gateway with no authentication | Release 1 is a local demonstration; production restrictions recorded as an Open Issue |

---

## 10. Open Issues

| # | Item | Status |
|---|---|---|
| 1 | Hosting for the Docker deployment | Open (from HLD) |
| 2 | Container registry | Open (from HLD); CI push uses a placeholder |
| 8 | Recovery from a cross-service commit mismatch | Manual correction in Release 1; automated reconciliation to be decided |
| 9 | Pinned JUnit version under Spring Boot 4.1 | Resolved in P1: Spring Boot 4.1.2 manages Jupiter 6.0.3; verified on Java 25 |
| 10 | Production policy for Swagger and docs routes (disable or protect) | New: to be decided before any non-local deployment |
| 11 | LLD revision to include deviations D-04, D-09, D-14, D-16, D-18, D-23 | New: LLD 1.1 |

LLD Open Issues 3–7 are closed by D-31.

---

## 11. Definition of Done

- [ ] All 16 user stories are implemented and every business rule (BR-01 to BR-25) is covered by unit tests.
- [ ] Every error code (LLD §21.2 plus `COMMON-429`) has a test; line coverage is at least 80% for both services.
- [ ] Spotless, Ruff and luacheck pass; all three CI pipelines are green.
- [ ] No direct SQL in application code; the CI search finds nothing.
- [ ] `/health`, `/ready` and Swagger work for both services, directly and through the gateway.
- [ ] Rate limiting behaves as in D-10 to D-14, including warm-up and fail-open.
- [ ] No CORS headers are returned; `/internal/*` is blocked at the gateway.
- [ ] Coloured startup banners show the agreed information and no secrets.
- [ ] Ctrl+C stops each service immediately and the log shows its resources closed.
- [ ] `make setup`, `make test`, `make up` and `make down` work on Windows (PowerShell) and on Linux or macOS.
- [ ] The root contains only documentation, orchestration and configuration; every project has a Dockerfile, `.dockerignore`, compose file, `.env.example`, Makefile and README.
- [ ] README, LICENSE, CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, TROUBLESHOOTING and CHANGELOG are complete.

---

## 12. Glossary

| Term | Meaning |
|---|---|
| Fail Open | When the rate-limit store cannot be reached, requests are allowed rather than blocked |
| Liveness | Whether a process is running and able to respond |
| OpenResty | An Nginx distribution with built-in Lua scripting |
| Readiness | Whether a service's dependencies are available, so it can serve requests |
| Sliding-window Log | A rate-limiting method that records each request's time and counts those in the last N seconds |
| Warm-up Period | The time after gateway start-up during which rate limiting is not enforced |
| uv | A Python package and project manager that uses `pyproject.toml` and a lock file |

LLD §32 terms also apply.

---

## 13. Review and Approval

| Role | Name | Signature | Date |
|---|---|---|---|
| Technical Lead | | | |
| Development Team Representative | | | |
| QA Representative | | | |
| DevOps Representative | | | |

---

*End of Document*
