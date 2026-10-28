# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Nothing yet.

## [1.0.0] - Unreleased

First release of the Kalash backend: a local demonstration of the savings
goal planner. Add the release date here when the `v1.0.0` tag is created
(see [CONTRIBUTING](CONTRIBUTING.md#releases)).

### Highlights

- All 16 user stories (KAL-BUC-00001 to 00016) and business rules BR-01 to
  BR-25: goals with insights (progress, remaining amount, suggested monthly
  saving, off-track, overdue), automatic Achieved and Active transitions,
  cancellation and permanent deletion, and deposits, withdrawals, edits,
  deletions and history.
- Goal Service (Java 25, Spring Boot 4.1.2) and Transaction Service
  (Python 3.14, FastAPI 0.136.3), each with its own PostgreSQL 18 database,
  ORM-only data access, RFC 9457 errors, correlation IDs, `/health` and
  `/ready`, OpenAPI documentation and immediate, clean shutdown.
- OpenResty API Gateway: one origin with a Redis sliding-window limit of 100
  requests per rolling minute per IP, a 30-second warm-up, fail-open
  behaviour and `COMMON-429` responses.
- Non-root images, a six-container Compose stack, Make targets with paired
  Bash and PowerShell scripts, backup and restore, and GitHub Actions
  pipelines for build, test, image and deployment.
- 444 unit tests: Goal 177 (98.43% line coverage), Transaction 187 (99.85%)
  and gateway 80 (99.65%).

### Known limitations

- Local demonstration only: no authentication or authorisation, and direct
  service and database ports are published (see [SECURITY](SECURITY.md)).
- Cross-service writes are not atomic. Mismatches are logged for manual
  correction.
- Image push and deployment wait on the registry and hosting decisions
  (plan Open Issues 1 and 2).
- No integration or end-to-end test suites. The React web app and the
  authentication service are outside this release.


### Added

- Phase 9 documentation and handoff:
  - the root README rewritten as the complete project guide;
  - ten architecture decision records in `docs/adr/`;
  - the LLD 1.1 update list;
  - an updated traceability matrix with business-rule test coverage;
  - these release notes.

- Phase 8 GitHub Actions:
  - `goal-service`, `transaction-service` and `gateway` pipelines, each with
    lint, tests with coverage gates, a direct-SQL search for the services,
    and coverage reports;
  - a shared `image` workflow that builds, checks non-root and pushes images
    tagged with the git SHA and the release version;
  - an SSH `deploy` workflow.
  - Actions are pinned to commit SHAs. Pushing and deploying wait on the
    registry and host settings.

- Phase 7 automation: a complete root `Makefile` (`setup`, `format`, `lint`,
  `test`, `test-goal`, `test-txn`, `test-gateway`, `coverage`, `run-goal`,
  `run-txn`, `migrate`, `backup`, `restore`, `clean` and the Compose
  lifecycle), a Makefile in every project, and eleven matching Bash and
  PowerShell scripts in `scripts/`. They work in PowerShell 7, Windows
  PowerShell 5.1 and Bash.
  - `make setup` checks the tools, creates missing `.env` files with
    generated development passwords (never printed), and installs the
    Transaction dependencies.
  - Goal targets use Java 25 on the host when available, and otherwise run
    Maven in a Java 25 container. Gateway targets run in its test image.
  - `make backup` and `make restore` implement LLD Section 29 with 7-day
    retention. Restore refuses the other database's dump, rolls back on
    failure and always restarts the owning service.
  - `make up` also waits for the host-published readiness URLs.

- Phase 6 unit-test audit against the implementation plan's test matrix and
  the LLD error catalogue, with new tests for the gaps: dedicated `GoalRules`
  and `StatusEvaluator` suites (BR-03 variants, the IST midnight boundary and
  the full status transition table), Goal readiness failing on a database
  outage while liveness stays up, and Transaction `type`/`goalId` validation.
  All three projects pass lint, tests and coverage: Goal 177 tests at 98.43%,
  Transaction 187 at 99.85%, gateway 80 at 99.65%.

- Phase 5 container images for all three projects, running as non-root
  user `kalash`, with pinned bases and OCI labels for version, git SHA,
  licence and commit time:
  - Goal Service: Maven Wrapper build, Spring Boot layered runtime on the
    Java 25 JRE, container-relative heap sizing and a bash `/dev/tcp`
    health probe.
  - Transaction Service: locked `uv sync` runtime environment and an
    entrypoint that runs `alembic upgrade head`, then `exec`s the service.
- Root `docker-compose.yml` for the full six-container stack:
  readiness-ordered start-up, health checks, `restart: unless-stopped`, named
  volumes, one network, LLD host ports, unpublished non-persistent Redis,
  short stop grace periods, log rotation and per-container secret scoping.
- Standalone compose files for the Goal (with goal-db), Transaction (with
  transaction-db) and gateway (with Redis) projects, plus `.dockerignore`
  files for every project.
- Root `Makefile` with `help`, `build`, `up`, `down`, `restart`, `ps` and
  `logs`; `make up` waits until every container is healthy.

- Phase 4 OpenResty 1.31 API Gateway: `/api/v1` routing with 10-second read
  timeouts, `/internal/*` and metrics blocked, documentation routes at
  `/docs/goals/` and `/docs/transactions/`, gateway and pass-through
  health/readiness, and a static landing page.
- Per-IP sliding-window rate limiter: one atomic Redis script, 100 requests per
  rolling 60 seconds on `/api/v1/*`, a 30-second uncounted warm-up, 429
  `COMMON-429` Problem Details with `Retry-After` and `X-RateLimit-*` headers,
  and fail-open with ERROR logging and a shared Redis back-off.
- Gateway correlation-ID validation and propagation, client-spoof-proof
  forwarded headers, a JSON access log with the rate-limit outcome, Problem
  Details for gateway 404/502/504, a validated start-up banner and shutdown logging.
- Gateway Dockerfile (runtime and Lua test stages), standalone `.env.example`
  and 80 busted specs with luacheck and luacov (99.65% line coverage).

- Phase 3 Transaction APIs for deposits, withdrawals, amount edits, deletion,
  newest-first history and history-first Cancelled-goal cleanup.
- Alembic transaction schema with CHECK constraints, descending history index
  and SQLAlchemy optimistic versioning; no seed data or cross-database foreign keys.
- Non-retrying Goal client with unchanged 4xx propagation, bounded timeouts,
  strict success validation and correlation forwarding.
- Flush-before-remote-call transaction sequencing, rollback/cancellation tests,
  confirmed/unknown remote-outcome mismatch logging and operator triage guidance.
- Phase 3 OpenAPI examples and 181 passing backend tests with 99.85% coverage.

- Phase 2 Goal Service business APIs: create, read, paginated overview, partial
  update and cancellation, plus internal snapshot, balance adjustment and deletion.
- Flyway goals migration, JPA optimistic versioning, unique-name enforcement,
  exact savings insights, lifecycle rules and fresh-transaction conflict retries.
- Goal request/success/error OpenAPI examples and unit coverage for all seven
  LLD worked calculations, validation, operation/status rules and retry limits.

- Phase 1 Goal Service (Spring Boot 4.1.2 / Java 25) and Transaction Service
  (FastAPI 0.136.3 / Python 3.14) foundations with standalone runtime guides.
- Validated configuration, injectable clocks, RFC 9457 error handling,
  correlation IDs, local/JSON logging and safe startup summaries.
- Database-aware readiness, process liveness, Swagger/OpenAPI and Prometheus
  endpoints, with no CORS and immediate shutdown/resource cleanup.
- Maven Wrapper, Spotless, JaCoCo, uv dependency lockfile, Ruff and foundation
  unit tests enforcing at least 80% backend line coverage.
- Phase 0 repository layout with persistent service, gateway, scripts,
  architecture-decision and future test-suite placeholders.
- Repository ignore rules, editor settings and explicit script line endings.
- MIT license, Contributor Covenant 2.1, contribution guidelines, security
  policy and initial troubleshooting guide.
- Root and project README skeletons, full-stack environment example, and
  GitHub pull request and issue templates.

### Changed

- The root compose file's application image names can be overridden with
  `KALASH_IMAGE_PREFIX` and `KALASH_IMAGE_TAG` (defaults `kalash` and
  `0.1.0`), so a deployment can pull registry images.

- The gateway image now runs entirely as a non-root user and carries OCI labels.
- The root `.env.example` targets the Compose stack and sets
  `APP_ROOT_PATH=/docs/transactions`. The gateway's standalone `.env.example`
  now defaults its upstreams to `host.docker.internal`.

- The root environment template adds `GOAL_SERVICE_UPSTREAM`,
  `TXN_SERVICE_UPSTREAM` and `GATEWAY_RESOLVER` for gateway upstream addressing.
- Transaction schema migration is now available through the explicit
  `uv run --locked alembic upgrade head` command before business API startup.
- Transaction test discovery uses importlib mode for mirrored feature modules.
- Goal startup now requires a reachable database for Flyway migration and
  Hibernate schema validation. A database outage after startup still marks
  readiness down without disabling process liveness.
- Goal amounts reject numeric-string coercion as well as decimals and overflow.
  PATCH distinguishes missing fields from explicit nulls; timestamps use
  PostgreSQL microsecond precision consistently.
