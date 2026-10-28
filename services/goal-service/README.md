# Goal Service

The Goal Service owns savings goals. It creates, edits and cancels them,
keeps each goal's balance and status (Active, Achieved, Cancelled), and
computes the savings insights. Its five public operations sit under
`/api/v1/goals`. Three internal operations under `/internal/v1/goals` let
the Transaction Service read a goal, adjust its balance and delete a
cancelled goal. It stores data in its own PostgreSQL database, `goal_db`, and
never calls the Transaction Service. Java 25, Spring Boot 4.1.2.

Release 1 is complete. The phase sections at the end of this README record
how each phase was verified. Decisions that affect this service are in the
[ADRs](../../docs/adr/README.md).

## Make targets

From this directory, `make help` lists the targets: `format`, `lint`,
`test`, `coverage`, `run`, `clean` and the Compose lifecycle (`build`, `up`,
`down`, `ps`, `logs`). They use Java 25 on the host when available. Otherwise
they run the Maven Wrapper in `maven:3.9.11-eclipse-temurin-25` with the
`kalash-goal-maven-cache` volume, so a host with Java 21 needs no JDK change;
`GOAL_RUNNER=host` or `docker` forces one. `make run` loads this directory's
`.env` into the process environment, which Spring does not do itself. Run
`make setup` at the repository root first to create the `.env`. See the
[scripts guide](../../scripts/README.md).

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

Run against a separately provisioned PostgreSQL 18 database. Flyway applies
[V1](src/main/resources/db/migration/V1__create_goals.sql) on startup, creating
the goals table, named CHECK constraints, case-insensitive unique-name index
and overview index. Hibernate then validates the schema (`ddl-auto=validate`);
it never creates or updates tables. No seed goals are inserted.

**P2 startup change:** the database must now be reachable and the user must
have migration privileges before startup can succeed. Invalid migration
history or schema mismatch fails startup rather than serving a partially
initialized application. Once started, a database outage returns readiness
503 while liveness stays available. Hikari connection acquisition times out
after two seconds.

The test profile disables Flyway and JDBC/JPA auto-configuration and removes
the database readiness indicator. Unit tests mock the repository and
transaction manager; do not deploy that profile. Never edit an applied
migration or enable automatic baselining to hide a mismatched database.

## Goal and balance APIs

| Method | Path | Success |
|---|---|---|
| POST | `/api/v1/goals` | 201 GoalResponse, with relative `Location` |
| GET | `/api/v1/goals?page=0&size=20` | 200 PageResponse of goals with current insights |
| GET | `/api/v1/goals/{goalId}` | 200 GoalResponse |
| PATCH | `/api/v1/goals/{goalId}` | 200 GoalResponse |
| POST | `/api/v1/goals/{goalId}/cancel` | 200 GoalResponse, with null insights |
| GET | `/internal/v1/goals/{goalId}` | 200 GoalSnapshot |
| POST | `/internal/v1/goals/{goalId}/balance-adjustments` | 200 GoalSnapshot |
| DELETE | `/internal/v1/goals/{goalId}` | 204, no body |

Create example (choose a target date after today in `APP_TIMEZONE`):

```json
{"name":"Goa Trip","targetAmount":50000,"targetDate":"2027-03-31"}
```

PATCH accepts any nonempty subset of `name`, `targetAmount`, `targetDate`;
omitted fields stay unchanged, and explicit nulls are rejected. Whole-rupee
amounts use signed 64-bit integers: decimal numbers, numeric strings and
out-of-range numbers return `400 COMMON-400`, never silent coercion.

Names are stripped before storage and checked case-insensitively, excluding
the same goal during edits. Cancelled goals still reserve their names until
deleted. The unique database index also resolves concurrent duplicate creates
as `409 GOAL-002`. The overview includes all statuses, sorted by target date,
then creation time, with UUID as a deterministic final tie-breaker.
Pagination is zero-based, defaults to 20 and allows sizes 1 through 100.

- Active goals may be edited. A supplied target date must be in the future;
  a supplied target amount must strictly exceed the current balance.
- Achieved goals allow only withdrawals or target-only raises. Raising the
  target above the balance reactivates the goal.
- Cancellation requires Active status and a zero balance.
- Cancelled goals are read-only; only internal deletion is permitted. P3's
  coordinator must delete transaction history before calling internal DELETE.
  A repeated DELETE after removal returns `404 GOAL-001`.

Internal adjustment example:

```json
{"operation":"DEPOSIT","delta":5000}
```

Deposits require Active status and a positive delta. Withdrawals allow Active
or Achieved status and require a negative delta. `TRANSACTION_EDIT` and
`TRANSACTION_DELETE` require Active status and allow either delta sign;
edits also allow zero for an unchanged amount, while deletion rejects zero.
Negative resulting balances return `422 GOAL-012`; arithmetic overflow returns
`400 COMMON-400`. Reaching or exceeding the target sets Achieved; withdrawing
below it reactivates the goal.

### Transactions and insights

The goal feature owns repository access. `GoalMutations` is its shared write
boundary used by both goal lifecycle and balance services; the balance feature
does not import the goal repository. Each write attempt runs in `REQUIRES_NEW`,
loads current state, reruns business checks and flushes before commit.
Optimistic conflicts allow **three retries after the initial attempt** (four
attempts maximum), then return `409 COMMON-409`. Other rejections are not retried.
No HTTP-level retries or distributed transaction guarantees are added.

Insights are computed on every read, never stored. Progress is uncapped and
rounded down to one decimal; remaining saving never goes negative. Suggested
monthly saving uses complete calendar months and ceiling division. Off-track
compares exact fractions, not rounded progress, avoiding floating-point and
integer multiplication overflow. Date rules use the injected timezone clock,
and the creation date is preserved on edits. Cancelled goals return null
insights; Achieved goals have zero remaining/monthly saving and no indicators.
UTC timestamps are normalized to PostgreSQL's microsecond precision before
the first response so later reads do not appear to change the creation instant.

## Health, documentation and observability

| Endpoint | Purpose |
|---|---|
| `/health` | Actuator liveness group; independent of database availability |
| `/ready` | Actuator readiness group including PostgreSQL; HTTP 503 when unavailable |
| `/actuator/health` | Aggregate health; details hidden |
| `/actuator/prometheus` | Prometheus metrics |
| `/swagger-ui` | Redirect to Swagger UI |
| `/v3/api-docs` | OpenAPI document with request, success and error examples |

Gateway contract: `/docs/goals/` should redirect to
`/docs/goals/swagger-ui`; proxy `/docs/goals/*` to this service with that prefix
stripped, setting **`X-Forwarded-Prefix: /docs/goals`** and the appropriate
forwarded host/protocol. Springdoc then generates gateway-prefixed asset and
schema URLs. OpenAPI explicitly advertises server **`/`**, not `/docs/goals`,
so "Try it out" requests target public `/api/v1/...` routes on the same
origin. Service-to-service operations use the `Internal` tag.
Trust forwarded headers only from your gateway: direct service ports should
not be publicly reachable in deployment.

No CORS configuration or `Access-Control-Allow-*` headers are added. No
authentication is introduced. The [gateway](../../gateway/README.md) (P4)
implements this contract and answers `/internal/*` with 404, but internal
routes stay reachable on this service's direct port; use local demonstration
data only.

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
`COMMON-400`. The P2 migration preserves these conventional CHECK names.
Unknown constraints remain sanitized `COMMON-500` errors.

Real-process acceptance checks are separate from the unit suite.

## Container

The [Dockerfile](Dockerfile) builds the jar with the Maven Wrapper on
`maven:3.9.11-eclipse-temurin-25`. Tests and Spotless are skipped there; they
run in `mvnw verify` and CI. It then copies Spring Boot's extracted layers onto
`eclipse-temurin:25.0.4.1_1-jre`, running as non-root user `kalash`
(uid 10001) with the `docker` profile. The JVM runs as PID 1 with
`-XX:MaxRAMPercentage=75`, so the heap follows the container memory limit
(1 GB in Compose, giving a 768 MB heap); override `JAVA_OPTS` to change it.
The image has no curl, so `healthcheck /health` (the image health check) and
`healthcheck /ready` (Compose) use bash's `/dev/tcp`. Labels carry the
version, git SHA, MIT licence and build commit time.

Standalone with its own database, from this directory:

```powershell
Copy-Item .env.example .env   # set GOAL_DB_PASSWORD; Bash: cp
docker compose up -d --build --wait
docker compose down           # add -v to delete the kalash-goal_goal-data volume
```

The [compose file](docker-compose.yml) reads only the database name, user,
password, timezone and log level from `.env`. The `localhost` and `local`
values there are for host runs and do not apply inside containers. It
publishes ports 8080 and 5432, the same as the root stack, so run one or the
other. The root [`make up`](../../README.md#5-quick-start-full-stack-in-docker)
runs this image in the full stack. `docker compose stop` ends with exit code
143, the JVM's normal status after SIGTERM, once JPA and Hikari have closed.

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

## P2 verification

Verified on 2026-10-27:

- `./mvnw -B -o spotless:apply verify` in the Java 25 Docker image with
  `--network none`: **150 tests passed, 98.43% line coverage (565/574)**.
  All seven LLD calculation examples, edge dates, exact-fraction comparisons,
  all twelve operation/status combinations, retry exhaustion, monetary
  overflow, PATCH omission/null distinctions and API error shapes are covered.
- Real PostgreSQL 18/JAR checks passed: initial Flyway migration and Hibernate
  validation, all eight operations, sorted pages, lifecycle transitions,
  timestamp stability, docs/examples, metrics, correlation and absent CORS.
- Twenty-four concurrent deposits produced 21 commits and 3 bounded
  `COMMON-409` conflicts in the final run; persisted balance equalled the
  successful count, with no lost or doubled update. Counts depend on scheduling.
- Concurrent duplicate creation produced exactly one 201 and one `GOAL-002`.
- Committed data survived application restart; migration reran idempotently.
  Database outage/recovery and signal-driven resource cleanup passed.
- Application code uses ORM/derived queries only; SQL is confined to the
  Flyway migration. Temporary acceptance containers/network were removed.

## P6 verification

Verified on 2026-10-28:

- `./mvnw -B -o spotless:apply verify` in the Java 25 Docker image with
  `--network none`: **177 tests passed, 98.43% line coverage (565/574)**.
- New `GoalRulesTest` and `StatusEvaluatorTest` test the business rules
  directly: name whitespace and case variants, target dates either side of
  IST midnight, strict target-above-balance bounds, Achieved/Cancelled edit
  limits and every status transition.
- New `ReadinessContextTest` uses the production readiness group
  (`readinessState,db`) with a stand-in database check: `/ready` returns 503
  `DOWN` while `/health` stays 200, and readiness recovers.

See the [root guide](../../README.md),
[contribution rules](../../CONTRIBUTING.md) and
[implementation plan](../../docs/Kalash_Project_Impl_Plan_Opus_v1.0.md).
