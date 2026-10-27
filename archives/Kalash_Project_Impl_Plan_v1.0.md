# Kalash Project Implementation Plan

**Requested deliverable:** `docs/Kalash_Project_Impl_Plan_v1.0.md`  
**Status:** Draft for review  
**Planning scope:** Greenfield backend and API gateway; no application code is being implemented in this planning step.

## 1. Problem and approach

Implement the Release 1 savings-goal and transaction capabilities described by the Kalash BRD, HLD, and LLD, together with the requested development, operational, and repository standards. The current workspace contains the design documents but no application source. Treat the work as a greenfield implementation, use the LLD as the detailed design baseline, and record any policy details not present in the supplied documents as requiring organizational review rather than inventing them.

The implementation scope is the Java Goal Service, Python Transaction Service, and NGINX API gateway. The React web application is excluded. No authentication, bank integrations, real-money movement, integration tests, or end-to-end tests are added in this phase.

## 2. Scope

### Included

- Goal creation, editing, cancellation, deletion of cancelled goals, goal overview/details, insights, and automatic status transitions.
- Deposits, withdrawals, transaction edits/deletes, transaction history, and cancelled-goal deletion coordination.
- The two-service PostgreSQL design and documented public/internal API contracts.
- Gateway-level IP rate limiting, OpenAPI/Swagger access, health/readiness endpoints, structured logging, startup information, and shutdown cleanup.
- Root and project-level Docker Compose files, Dockerfiles, `.dockerignore` files, Make targets, scripts, tests, configuration, and repository governance documentation.
- Unit tests only, with persistence, inter-service calls, and rate-limit storage mocked as appropriate.

### Excluded

- React/web UI implementation.
- Authentication/authorization, bank connections, money movement, and external integrations.
- Integration and end-to-end test suites for now.
- Cloud hosting or production deployment design beyond documenting development-versus-production Swagger restrictions.

## 3. Confirmed design decisions

| Area | Decision |
|---|---|
| Workspace | Greenfield backend and gateway implementation; no source files at repository root |
| Service stack | Follow the Java/Spring Boot Goal Service, Python/FastAPI Transaction Service, PostgreSQL, and NGINX gateway in the supplied HLD/LLD |
| Persistence | Runtime database access through ORM/repositories only. Flyway/Alembic schema migration scripts are allowed. |
| Rate limiting | One gateway-global limit per client IP, exact rolling 60-second window, maximum 100 requests, no additional burst |
| Warm-up | Bypass enforcement for the first 30 seconds after gateway startup; do not count requests during that grace period |
| Rate-limit store | Redis; if unavailable, fail closed with a service-unavailable response and do not forward API requests |
| Rate-limit response | HTTP 429 with `Retry-After` when the remaining wait can be determined |
| Client IP | Determine the client IP at the trusted NGINX boundary; trust forwarded IP information only from configured trusted proxies |
| OpenAPI/Swagger | Document each microservice; serve browser-accessible Swagger through same-origin NGINX routes in development and disable or restrict it in production |
| Health | Separate liveness and readiness endpoints; readiness checks required dependencies |
| CORS | Disabled; do not add CORS middleware or CORS response headers |
| Shutdown | On Ctrl+C, stop promptly and clean up resources without draining in-flight requests. This accepts the cross-service consistency risk described below. |
| Tests | Unit tests only at this stage; no live database/Redis dependency in unit tests |
| Copyright | MIT License with “Kalash Financial Services” copyright |
| Policy basis | Apply explicit requirements and supplied design documents; do not claim compliance with unspecified internal policies |

The exact NGINX/Redis integration mechanism must be selected and validated during detailed design. An NGINX-native smooth/leaky-bucket directive alone does not satisfy the confirmed exact rolling-window rule. Evaluate an NGINX-compatible programmable gateway option (for example, OpenResty with an atomic Redis-backed sliding-window operation) before implementation; do not silently substitute an approximate limiter.

## 4. Proposed repository organization

Keep application source inside project directories. Put only documentation, repository configuration, scripts, tests that are genuinely repository-wide, and orchestration files at the root.

```text
/
├── README.md
├── LICENSE
├── Makefile
├── .gitignore
├── .env.example
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── SECURITY.md
├── TROUBLESHOOTING.md
├── CHANGELOG.md
├── docker-compose.yml
├── docs/
│   ├── Kalash_LLD_v1.0.md
│   ├── Kalash_HLD_v1.1.md
│   ├── Kalash_BRD_v1.0.md
│   └── Kalash_Project_Impl_Plan_v1.0.md
├── scripts/
├── goal-service/
│   ├── .dockerignore
│   ├── docker-compose.yml
│   └── src/ (application and unit tests)
├── transaction-service/
│   ├── .dockerignore
│   ├── docker-compose.yml
│   ├── app/
│   └── tests/
└── gateway/
    ├── .dockerignore
    ├── docker-compose.yml
    ├── configuration and rate-limit implementation
    └── tests/
```

Each project-level Compose file should support that project’s local development needs. The root Compose file should orchestrate the complete backend stack, including the two PostgreSQL databases, gateway, and Redis. The actual division of shared Compose configuration should be settled while scaffolding to avoid duplicated or conflicting settings.

## 5. Implementation phases

### Phase 1 — Repository foundation and governance

- Establish the repository/project layout and ensure no application source is placed at root.
- Add the root README, `.gitignore`, MIT license, `.env.example`, Makefile, and requested governance/operations documents.
- Define shared conventions for API errors, correlation IDs, environment configuration, logging, and documentation comments.
- Add project-local test and script locations.

### Phase 2 — Goal Service

- Implement the goal entity, repository/ORM mapping, migration, DTOs, validation, business rules, and public/internal API endpoints.
- Implement status evaluation, balance adjustment, and on-read insights using an injected IST clock.
- Preserve the LLD business rules and error catalogue, including optimistic locking and problem-details responses.
- Add OpenAPI/Swagger, separate health/readiness endpoints, structured logs, a non-secret colored startup banner, and immediate shutdown cleanup.
- Add unit tests for business rules, status transitions, insight calculations, and API behavior using mocked persistence.

### Phase 3 — Transaction Service

- Implement SQLAlchemy models/repositories and migrations, Pydantic schemas, transaction business logic, and public APIs.
- Implement deposit, withdrawal, edit/delete delta calculations, history pagination, and cancelled-goal deletion coordination through the Goal Service internal API.
- Use environment-based settings, structured logs, correlation propagation, explicit timeout/error mapping, and RFC 9457-style problem responses.
- Add OpenAPI/Swagger, separate health/readiness endpoints, a non-secret colored startup banner, and immediate cleanup of HTTP and database resources on shutdown.
- Add unit tests with mocked repositories and Goal Service client; cover failure and rollback behavior.

### Phase 4 — Gateway and exact rate limiter

- Configure NGINX as the API entry point and keep internal routes inaccessible from the public gateway.
- Select and validate the programmable NGINX/Redis integration needed for exact rolling-window behavior.
- Implement the global per-IP rolling counter atomically in Redis; enforce the startup grace, 100/60-second ceiling, no-burst rule, 429 response, and `Retry-After`.
- Define trusted proxy handling and prevent untrusted forwarded headers from controlling the rate-limit key.
- Fail closed if Redis is unavailable; return an explicit service-unavailable response and log the limiter failure without exposing secrets.
- Route development Swagger/OpenAPI through the gateway and disable/restrict documentation routes outside development.
- Add gateway unit tests with a mocked counter store and clock for boundary, warm-up, proxy-IP, 429, and Redis-failure behavior.

### Phase 5 — Containers and local orchestration

- Add project-level Dockerfiles and `.dockerignore` files.
- Add the root Compose stack for the gateway, Goal Service, Transaction Service, both databases, and Redis.
- Add usable project-level Compose configurations for standalone development.
- Configure health checks and dependency ordering without treating a liveness check as a readiness check.
- Keep secrets out of source control; use ignored local `.env` files and committed examples.

### Phase 6 — Unit-test and quality gates

- Cover all 16 BRD user stories and associated business rules with unit tests.
- Use fixed clocks for date-dependent behavior and mocks/fakes for persistence, HTTP clients, and Redis.
- Do not add Testcontainers, integration tests, or E2E tests in this phase.
- Provide Make targets for formatting, linting, unit tests, builds, local run, and Compose lifecycle.
- Verify that the language-specific documentation comments cover major public/business classes and methods.

### Phase 7 — Documentation and handoff

- Complete the root README with architecture, scope, setup, environment variables, API/docs/health URLs, Make targets, testing, Compose usage, and links to the support documents.
- Complete Contributing, Code of Conduct, Security, Troubleshooting, and Changelog documents.
- Keep the implementation plan and other design material under `docs/`.
- Review the repository tree to confirm source code is project-scoped and each project has a `.dockerignore` and Compose support.

## 6. Unit-test coverage map

- **Goal Service:** create/edit/cancel/delete rules; uniqueness and validation; balance constraints; achieved/active transitions; progress, remaining balance, suggested saving, off-track and overdue calculations; pagination/order; error mapping; concurrency behavior through mocked repositories.
- **Transaction Service:** deposit/withdrawal deltas; transaction edit/delete; transaction date behavior; history pagination; goal status and balance restrictions; Goal Service timeout/unavailable/problem responses; local rollback behavior.
- **Gateway/limiter:** global shared counter semantics; exact 60-second boundary; no-burst limit; 30-second startup exemption and empty counter at grace end; trusted-proxy IP extraction; 429 and `Retry-After`; fail-closed Redis errors; documentation route policy.

## 7. Risks and explicit follow-ups

- **Immediate shutdown consistency:** An in-flight transaction may have updated the Goal Service before the Transaction Service commits. Immediate termination can leave the two databases inconsistent. Preserve the requested no-drain behavior, log any detected mismatch with correlation ID/goal ID/delta, and document manual recovery for this release. Automated reconciliation remains outside scope unless separately approved.
- **Rate-limit implementation:** Exact rolling behavior requires more than the standard NGINX smooth limiter. Validate the selected NGINX-compatible Redis integration, atomicity, and operational dependencies before coding.
- **Restart grace:** Each gateway restart creates a new 30-second enforcement bypass. Document this accepted behavior and ensure startup logs/metrics make it observable.
- **Organizational policies:** No separate internal policy document has been supplied. The plan follows explicit requirements and the design documents; organizational review is required before representing the result as fully policy-compliant.
- **Technology versions:** Treat versions in the approved design documents as targets. Validate compatibility before implementation and request a decision rather than silently changing the stack.
- **Shutdown timeout:** No request-drain timeout applies because immediate shutdown was selected. Resource cleanup must still close clients/pools and roll back locally owned transactions where possible.

## 8. Acceptance gates

- All specified business endpoints and business rules are represented in the implementation and have unit coverage.
- Runtime database access is ORM/repository based; only migration scripts may contain SQL.
- All API services expose OpenAPI/Swagger through the approved development-only gateway route policy.
- Liveness and readiness are separate and have distinct semantics.
- Rate limiting follows the exact approved semantics, including warm-up, IP trust, Redis failure, and response behavior.
- CORS remains disabled; internal APIs are not exposed through NGINX.
- Ctrl+C performs the approved immediate stop and closes owned resources.
- The root contains no application source; required root/project documentation, configs, Dockerfiles, `.dockerignore`, and Compose files are present.
- Unit tests and the agreed Make targets run successfully; no integration or E2E suite is introduced in this phase.
