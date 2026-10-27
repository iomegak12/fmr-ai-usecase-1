# Goal Service

**Phase 1: runnable cross-cutting foundation.** No business endpoints, entities,
tables or migrations exist yet. Goal, balance and insight features, including
Flyway migrations, begin in P2. This service never calls the Transaction Service.

## Build and unit tests

Requires **Java 25**. The generated Maven Wrapper downloads Maven **3.9.11**;
no global Maven installation is needed. Spring Boot **4.1.2**, springdoc **3.2.0**,
Spotless **3.6.0** (google-java-format **1.34.1**) and JaCoCo **0.8.14** are pinned.
JUnit Jupiter **6.0.3**, Mockito **5.23.0** and AssertJ **3.27.7** are managed by
Spring Boot and verified from the resolved dependency tree. Jupiter retains
the `org.junit.jupiter` API; this resolves the plan's JUnit-version open issue
without overriding Boot's supported BOM. The verified isolated build runtime
is Temurin **25.0.1+8**, with Spring Framework **7.0.10**.

From this directory in PowerShell:

```powershell
.\mvnw.cmd spotless:apply
.\mvnw.cmd verify
java -jar .\target\goal-service-0.1.0-SNAPSHOT.jar
```

On Linux/macOS use `./mvnw`. `verify` enforces formatting and at least **80% line
coverage across all production classes**, with no coverage exclusions. Unit tests
use mock servlet requests, fixed clocks and the `test` profile: no database,
containers, sockets or network calls. Reports are in `target/surefire-reports`
and `target/site/jacoco/index.html`.

If the host has only Java 21, use an isolated Java 25 Docker build (do not
change the machine's `JAVA_HOME`):

```powershell
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/workspace" `
  --mount "type=volume,source=kalash-goal-p1-maven-cache,target=/root/.m2" `
  -w /workspace maven:3.9.11-eclipse-temurin-25 ./mvnw -B verify
```

Container paths in these Docker arguments are Linux paths. Host paths remain
Windows paths.

## Configuration and local run

Copy `.env.example` only as a private reference; **Spring does not load `.env`
automatically**. Export the values in your shell or provide them through your
process/container environment. Never put passwords on the Java command line.

| Variable | Default |
|---|---|
| `SPRING_PROFILES_ACTIVE` | `local` |
| `GOAL_SERVICE_PORT` | `8080` |
| `APP_TIMEZONE` | `Asia/Kolkata` |
| `LOG_LEVEL` | `INFO` |
| `GOAL_DB_HOST` | `localhost` (`goal-db` in `docker`) |
| `GOAL_DB_PORT` | `5432` |
| `GOAL_DB_NAME` | `goal_db` |
| `GOAL_DB_USER` | `goal_user` |
| `GOAL_DB_PASSWORD` | empty; supply privately for PostgreSQL |

Run against a separately provisioned PostgreSQL 18 database. P1 neither creates
nor changes schema (`ddl-auto=none`, no Flyway dependency yet). Startup tolerates
an unavailable database, but readiness fails. Hikari connection acquisition
times out after two seconds. The test profile deliberately excludes JDBC/JPA
auto-configuration and removes the database readiness indicator; do not deploy
that profile.

## Health, documentation and observability

| Endpoint | Purpose |
|---|---|
| `/health` | Actuator liveness group; independent of database availability |
| `/ready` | Actuator readiness group including PostgreSQL; HTTP 503 when unavailable |
| `/actuator/health` | Aggregate health; details hidden |
| `/actuator/prometheus` | Prometheus metrics |
| `/swagger-ui` | Redirect to Swagger UI |
| `/v3/api-docs` | OpenAPI document (no P2 business paths yet) |

Gateway contract: `/docs/goals/` should redirect to
`/docs/goals/swagger-ui`; proxy `/docs/goals/*` to this service with that prefix
stripped, setting **`X-Forwarded-Prefix: /docs/goals`** and the appropriate
forwarded host/protocol. Springdoc then generates gateway-prefixed asset and
schema URLs. OpenAPI explicitly advertises server **`/`**, not `/docs/goals`,
so future "Try it out" requests target public `/api/v1/...` routes on the same
origin. Future service-to-service operations must use the `Internal` tag.
Trust forwarded headers only from your gateway: direct service ports should
not be publicly reachable in deployment.

No CORS configuration or `Access-Control-Allow-*` headers are added. No
authentication is introduced in P1.

Incoming `X-Correlation-ID` values containing 1–128 ASCII letters, digits,
periods, underscores or hyphens are reused; missing/unsafe values become UUIDs.
The ID is echoed before controller execution, propagated across error
redispatch, added to MDC and restored/cleared after processing. Request logs
include method, status and duration; bodies, query strings and credentials
are not logged.

Local logs are human-readable with UTC timestamps and correlation IDs; Docker
logs are ECS JSON. The startup summary lists identity, network URLs, database
host/port/name and settings, never credentials. Summary colour requires a TTY,
absence of `NO_COLOR`, and a non-Docker profile. `NO_COLOR` also disables Spring
console colouring. Ctrl+C/SIGTERM uses immediate server shutdown; Spring closes
JPA, Hikari and executors. Lifecycle and native Hikari shutdown-completion logs
record cleanup.

## Error framework

The complete LLD 21.2 catalogue and `COMMON-429` are available in `ErrorCode`.
`ApiException` exposes only catalogue-approved descriptions. Advice returns
RFC 9457 `application/problem+json` with `errorCode`, `correlationId`, UTC
`timestamp`, and `errors[]` **only for validation failures**. Unexpected errors
are sanitized; rejected field values and SQL/driver messages are never echoed.
Framework statuses such as 404/405 retain their status without inventing
business catalogue codes.

Database mapping uses structured Hibernate/PostgreSQL metadata, not message
matching. `ux_goals_name_ci` maps to `GOAL-002`; PostgreSQL's conventional
`goals_balance_check` maps to `GOAL-012`; `goals_target_amount_check`,
`goals_status_check` and known required goal-field NOT NULL violations map to
`COMMON-400`. The LLD names the unique index but not CHECK constraints; P2
migrations must preserve these conventional names or update this mapping.
Unknown constraints remain sanitized `COMMON-500` errors.

Dockerfiles/Compose, Make targets and CI remain deferred to their planned
phases. Real-process acceptance checks are separate from the unit suite.

## P1 verification

Verified on 2026-10-27:

- `./mvnw -B -q spotless:apply verify`: passed.
- `./mvnw -B -o verify` in the Java 25 Docker image with `--network none`:
  passed; **55 tests, zero failures/errors**, **96.49% line coverage**
  (165/171 lines), including MVC slice and mock-context checks.
- The executable JAR was run against a short-lived PostgreSQL 18 instance in
  both `local` and `docker` profiles. Health, readiness, Swagger UI, OpenAPI,
  Prometheus, forwarded documentation prefix, error correlation and absence of
  CORS headers passed. A database outage returned readiness 503 while liveness
  stayed 200, and readiness recovered after restart.
- Docker ECS identity/correlation fields and secret-free logs passed. Real
  pseudo-TTY startup colour and `NO_COLOR` suppression both passed. SIGTERM
  completed in under one second, with JPA/Hikari cleanup logged.
- Acceptance containers and the isolated network were removed. Generated
  reports/logs remain under ignored `target`; no integration suite was added.

See the [root guide](../../README.md),
[contribution rules](../../CONTRIBUTING.md) and
[implementation plan](../../docs/Kalash_Project_Impl_Plan_Opus_v1.0.md).
