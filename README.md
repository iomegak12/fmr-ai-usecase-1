# Kalash - Savings Goal Planner

Kalash Release 1 is a local demonstration backend for savings goals and
transactions, fronted by an API Gateway.

**Current status: Phase 1 cross-cutting service foundations implemented.**
Both backend services now run with health/readiness endpoints, API
documentation, correlation IDs, profile-based logging and shutdown cleanup.
Goal and Transaction business APIs, migrations, the gateway, Compose files,
Make targets and CI/CD remain in their later phases.

## Scope and planned architecture

- **Goal Service:** goal lifecycle, balances and savings insights.
- **Transaction Service:** deposits, withdrawals, transaction history and
  cancelled-goal deletion coordination.
- **API Gateway:** public routing and Redis-backed rate limiting.
- Each backend service owns its own PostgreSQL database.
- The Transaction Service may call the Goal Service; the reverse is prohibited.

The React frontend, authentication/profile service and integration/e2e suites
are outside this implementation's Release 1 scope. There is no back-end
authentication; see the [security limitations](SECURITY.md).

## Repository layout

| Location | Purpose |
|---|---|
| [services/goal-service](services/goal-service/README.md) | Java / Spring Boot Goal Service foundations |
| [services/transaction-service](services/transaction-service/README.md) | Python / FastAPI Transaction Service foundations |
| [gateway](gateway/README.md) | OpenResty / Lua API Gateway scaffold |
| [docs](docs/) | Requirements, designs and implementation plans |
| [docs/adr](docs/adr/README.md) | Future architecture decision records |
| [scripts](scripts/README.md) | Future paired Bash and PowerShell automation |
| [tests/integration](tests/integration/README.md) | Deferred integration-test suite |
| [tests/e2e](tests/e2e/README.md) | Deferred end-to-end test suite |
| [.github](.github/) | Pull request and issue templates; future workflows |

The root contains documentation, orchestration and repository configuration
only, not application source. Empty scaffold directories contain `.gitkeep`
files so they survive Git clones; remove each placeholder when that directory
gains real content. Test package directories mirror their production packages.
Existing archived documents are retained without modification.

## Technology stack

| Component | Target |
|---|---|
| Goal Service | Java 25, Spring Boot 4.1.2, Maven Wrapper, springdoc 3.2.0 |
| Transaction Service | Python 3.14, FastAPI 0.136.3, Pydantic 2, SQLAlchemy 2, Alembic, uv |
| Gateway | OpenResty, Lua, Redis |
| Persistence | PostgreSQL 18.x, separate database per service |
| Tooling | Docker Compose v2, GNU Make, Bash and PowerShell |

P1 compatibility was verified with Java 25.0.1 and Python 3.14.2 against
PostgreSQL 18. Spring Boot manages JUnit Jupiter 6.0.3 (the Jupiter API retained
from JUnit 5). The gateway and orchestration entries remain design targets.

## Getting started at Phase 1

1. Read the [Opus implementation plan](docs/Kalash_Project_Impl_Plan_Opus_v1.0.md),
   particularly the decision register and the next phase's tasks.
2. Read the [contribution guidelines](CONTRIBUTING.md).
3. Follow the standalone [Goal Service guide](services/goal-service/README.md)
   and [Transaction Service guide](services/transaction-service/README.md).
   Use their local environment examples and supply unique development
   passwords. Never overwrite an existing `.env` or commit it.
4. Provide each service's own PostgreSQL database. No tables are needed yet:
   schema migrations arrive with the business features.

Java 25 is required to build/run the Goal Service; Java 21 is insufficient.
P1 validation used Java 25 in Docker without changing the host JDK. Python
dependencies and its runtime are managed through uv and the service lockfile.

The Transaction Service loads its service-local `.env` automatically. Spring
does not: export the Goal Service variables into the launching process as
documented in its README.

`make setup`, `make up` and other root targets are not implemented yet.
See [Windows Make guidance](TROUBLESHOOTING.md#gnu-make-on-windows) when
preparing for the automation phase.

### Available endpoints

| Purpose | Goal Service (default port 8080) | Transaction Service (default port 8000) |
|---|---|---|
| Liveness | `/health` | `/health` |
| Database readiness | `/ready` | `/ready` |
| Swagger UI | `/swagger-ui` | `/docs` |
| OpenAPI | `/v3/api-docs` | `/openapi.json` |
| Metrics | `/actuator/prometheus` | `/metrics` |

Readiness depends only on each service's own database; liveness does not.
Requests with an `Origin` header receive no CORS headers. Documentation and
health are available now, but no goal or transaction business API is implemented.

## Configuration

The root [.env.example](.env.example) covers every variable in
[implementation plan Section 6](docs/Kalash_Project_Impl_Plan_Opus_v1.0.md#6-configuration-matrix).
It targets the **full-stack Docker network**, with both service profiles set
to `docker`; passwords are deliberately blank and must be set locally.

Host-run services will use the `local` profile, reachable host addresses and
published ports instead. In particular, both database container ports are
`5432`, while the planned Transaction database host port is `5433`.
Project-specific examples are in each service directory. The Transaction
Service's additional `APP_ROOT_PATH` controls documentation proxy routing;
leave it empty for direct access. Leave `TRUSTED_PROXIES` empty unless a trusted
proxy is explicitly configured. Set `NO_COLOR` to disable console colours.

## Testing and automation

Foundation unit tests now cover both backend services. Business tests will be
added alongside P2/P3; gateway tests arrive with P4. Both backend services
enforce at least 80% line coverage; planned gateway coverage has no numeric gate.
See the
[test and quality requirements](CONTRIBUTING.md#tests-and-quality-gates).

Run from the respective service directory:

| Service | Command | P1 result |
|---|---|---|
| Goal | `.\mvnw.cmd verify` on Windows / `./mvnw verify` on Bash, using Java 25 | Equivalent Docker wrapper verification passed: 55 tests, 96.49% line coverage |
| Transaction | `uv run --locked ruff check .` | Passed |
| Transaction | `uv run --locked ruff format --check .` | Passed |
| Transaction | `uv run --locked pytest` | 73 tests passed, 99.73% line coverage |

Goal verification used `maven:3.9.11-eclipse-temurin-25`, with dependencies
cached, running `./mvnw -B -o verify` with Docker networking disabled.
The Goal build includes Spotless and JaCoCo; Transaction tests use pytest-cov.
Unit tests use test doubles, not databases or network calls.

Separate real-process smoke checks against temporary PostgreSQL 18 instances
verified direct endpoints, database-down readiness, correlation, absent CORS,
safe startup logging and signal-driven resource cleanup. These checks do not
constitute a committed integration/e2e suite; those folders remain placeholders.

The current Python dependency set emits one upstream Starlette/AnyIO
deprecation warning in tests; no tests fail. If VS Code still reports unresolved
Python imports, select `services/transaction-service/.venv/Scripts/python.exe`
on Windows (or `.venv/bin/python` within that service on Unix).

Application Dockerfiles, Compose, Makefiles, scripts and GitHub Actions will
be added in later phases.

## Documentation index

- [Business requirements v1.0](docs/Kalash_BRD_v1.0.md)
- [High-level design v1.1](docs/Kalash_HLD_v1.1.md)
- [Low-level design v1.0](docs/Kalash_LLD_v1.0.md)
- [Opus implementation plan v1.0 - execution reference](docs/Kalash_Project_Impl_Plan_Opus_v1.0.md)
- [Archived alternative implementation plan v1.0](archives/Kalash_Project_Impl_Plan_v1.0.md)
- [Architecture decision records](docs/adr/README.md)

This README is a skeleton. P9 will complete the architecture diagram, runnable
quick start, service URLs, API/error catalogue, full configuration reference,
rate limiting, logging, lifecycle, containers, CI/CD and backup/restore guide
against the implemented system.

## Governance

- [License - MIT](LICENSE)
- [Code of Conduct - Contributor Covenant 2.1](CODE_OF_CONDUCT.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy and reporting](SECURITY.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Changelog](CHANGELOG.md)
- [Pull request template](.github/PULL_REQUEST_TEMPLATE.md)
- [Bug report template](.github/ISSUE_TEMPLATE/bug_report.md)
- [Feature request template](.github/ISSUE_TEMPLATE/feature_request.md)
