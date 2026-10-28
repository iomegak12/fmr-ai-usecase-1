# Troubleshooting

## Before you start

`make setup` then `make up` runs the full stack in Docker (see the
[quick start](README.md#5-quick-start-full-stack-in-docker)), and each project
also has its own Makefile and compose file. `make run-goal` and
`make run-txn` run the services on the host. `make help` lists every target,
and the [scripts guide](scripts/README.md) explains them. Most problems below
show up first in `make ps` (health) and `make logs`; search the logs for the
`correlationId` returned in the failing response.

## Service startup and runtime versions

- Goal Service requires Java 25, not Java 21. Set `JAVA_HOME` and `PATH` only
  for the shell running the build, or use the JDK 25 Docker approach in the
  service guide. Do not change a shared machine's JDK for other projects.
- Goal Service does not automatically read `.env`; export its database and
  profile settings before launching Spring.
- Goal Service now requires the database at startup: Flyway must migrate it
  successfully before Hibernate validates the schema. A database that is down
  at startup no longer permits the Goal application to start. An outage after
  startup still leaves process liveness available while readiness returns 503.
- Transaction Service uses Python 3.14 via `uv sync --locked`. Run it from its
  own directory with `uv run --locked python -m app`, so its `.env` is loaded
  and the correct Windows async loop is selected.
- Apply its schema first with `uv run --locked alembic upgrade head` from the
  Transaction Service directory. A connectivity-only readiness probe does not
  certify that schema migrations were applied.
- The root `.env.example` is for the full-stack Compose network. Its
  container hostnames will not resolve for host-run services.
- Both service examples leave passwords blank intentionally. Set a matching
  local database credential; never post it in an issue.
- If `/health` returns 200 but `/ready` returns 503, check the service's own
  database address, port, credentials and availability. The Goal Service
  being offline must not make Transaction readiness fail.

Never share `.env` files, passwords, financial records or unredacted logs in
issues. Include the operating system, commit, affected component, redacted
error and reproduction steps when asking for help.

## Ports already in use

Host ports are gateway `80`, Goal Service `8080`, Transaction Service
`8000`, Goal database `5432` and Transaction database `5433`. The root stack
and the project stacks publish the same ports, so run one or the other, and
stop host-run services before starting containers on their ports.

- Windows PowerShell: inspect listeners with
  `Get-NetTCPConnection -State Listen -LocalPort 80,8080,8000,5432,5433`
  and identify the returned owning PID with `Get-Process -Id <PID>`.
- Linux: inspect listeners with `ss -ltnp`.
- macOS: inspect listeners with `lsof -nP -iTCP -sTCP:LISTEN`.
- Stop only a process you own and have identified, or change the host side
  of the `ports:` mapping in the compose file (for example `"8081:8080"`).
  Do not indiscriminately terminate shared processes.

Both databases use port `5432` inside the Docker network; host port `5433` for
the Transaction database must not become its container-side connection port.

## Docker is not running

Use `docker info` to confirm daemon access and
`docker compose version` to confirm the Compose v2 plugin. Start Docker Desktop
on Windows or macOS, or the Docker daemon through your Linux service manager.
On Windows, check that Docker Desktop's WSL 2 backend is ready. Do not reset
Docker or delete volumes to resolve a daemon startup problem.

## GNU Make on Windows

PowerShell does not include GNU Make. Install it through an approved package
manager (for example, `winget install --id GnuWin32.Make --exact` where
available), ensure its executable directory is on `PATH`, reopen the terminal
and verify `make --version`. WSL with GNU Make is another option; keep tools
and project paths consistent within the selected environment.

On Windows, Make runs the `.ps1` scripts with PowerShell 7 (`pwsh`). Without
PowerShell 7, add `POWERSHELL=powershell` to use Windows PowerShell 5.1. From
Git Bash, `SCRIPT_SHELL=sh` runs the `.sh` scripts instead. Without Make, run
the scripts directly, for example `pwsh scripts/test.ps1` or
`bash scripts/test.sh`; see the [scripts guide](scripts/README.md).

## Make target problems

- **`pwsh` is not recognized:** install PowerShell 7, or run
  `make <target> POWERSHELL=powershell`.
- **Goal targets download Maven or take minutes the first time:** the host
  has no Java 25, so Maven runs in `maven:3.9.11-eclipse-temurin-25`. The
  first run fills the `kalash-goal-maven-cache` volume and needs network
  access; later runs reuse it. Use `GOAL_RUNNER=host` to force the host JDK,
  which must then be Java 25.
- **`uv is required`:** install uv 0.9 or newer, then run `make setup`.
- **`.env is missing; run 'make setup'`:** `make run-goal`, `make run-txn` and
  `make migrate` read the service's own `.env`. Run `make setup`, which
  creates it without changing existing files.
- **`make run-goal` fails with a password error:** the service `.env` and the
  database volume disagree. Volumes keep the password they were first created
  with. Copy the password from the `.env` used to create the volume, or
  remove the volume (this deletes its data).
- **`goal-db is not running` from backup or restore:** both scripts act on
  the root stack only. Start it with `make up`.
- **Ports 8080 or 8000 are busy for `make run-goal` or `make run-txn`:** stop
  the stack's service container first, for example
  `docker compose stop goal-service`.

## Docker Compose stack

- **"required variable GOAL_DB_PASSWORD is missing a value"** (or
  `TXN_DB_PASSWORD`): copy `.env.example` to `.env` next to the compose file
  you are running and set the password. Blank values are rejected on purpose.
- **Changed a database password after the first start**: PostgreSQL keeps the
  password it was initialised with in its volume. Revert the change, or, for
  disposable local data only, remove the volume (`docker compose down -v`)
  and start again.
- **`make up` fails with a container "unhealthy" or "exited"**: run `make ps`
  and `docker compose logs <service>`. Typical causes: a port conflict
  (above), a database credential mismatch, or a failed migration. The
  Transaction container runs `alembic upgrade head` first and exits if it
  fails; the Goal container needs Flyway to succeed. Readiness gates the
  start-up order, so the gateway starts only after both services are ready.
- **First build is slow or fails offline**: the images download Maven
  plugins, Python packages and base images. Later builds use the cache.
- **Goal Service exit code 143 after `docker compose stop`/`down`**: this is
  the JVM's normal status after SIGTERM (128 + 15), not a crash. The log shows
  the shutdown and Hikari closing.
- **Project stacks cannot reach each other**: the project compose files talk
  to each other through ports published on the Docker host
  (`host.docker.internal`). Start the stack being called first and check its
  host port. On Linux the gateway project needs `GOAL_SERVICE_UPSTREAM` and
  `TXN_SERVICE_UPSTREAM` set to the host bridge address (for example
  `172.17.0.1:8080`), because nginx resolves names through DNS only.
- **Root and project stacks hold different data**: each Compose project has
  its own volumes (`kalash_*`, `kalash-goal_*`, `kalash-transaction_*`).
  This is by design.
- **Goal Service runs out of memory**: its container is limited to 1 GB with
  the heap at 75% of that. Raise `mem_limit` in the compose file rather than
  setting a fixed `-Xmx`.

## Migration failures

Goal Service uses Flyway V1; Transaction Service uses Alembic revision
`0001_create_transactions`:

1. Read the first migration error in the affected service's redacted logs.
2. Check database availability and the relevant host, port, database name,
   username and locally configured password.
3. Use Docker service names inside containers; use `localhost` and published
   host ports for host-run services.
4. Goal Service migrations use Flyway on startup; Transaction Service migrations
   use the explicit `uv run --locked alembic upgrade head` command. Inspect
   migration history before changing a migration. `uv run --locked alembic check`
   detects ORM metadata drift.
5. Do not edit an already-applied migration, reset a shared database or delete
   volumes as a shortcut. Back up any data that must be preserved and escalate
   conflicting migration history to the maintainer.

The root environment example targets the Docker network. It is not a ready-made
host-run configuration.

## Goal API rejections

- `400 COMMON-400`: check required fields, UUID/date formats, page limits and
  integer amounts. A PATCH must contain an editable field, omit unchanged
  fields rather than sending nulls, and use JSON numbers rather than numeric
  strings.
- `409 GOAL-002`: names are case-insensitively unique after trimming, including
  names reserved by Cancelled goals. The unique index handles creation races.
- `409 COMMON-409`: the server exhausted three fresh-state retries after the
  initial optimistic write attempt. The failed request did not apply its
  balance adjustment; inspect current state before deciding on further action.
  Do not blindly retry requests whose outcome is unknown after a network timeout.
- `422 GOAL-005`: Achieved goals permit only target-only raises; Cancelled
  goals are read-only. Consult the remaining catalogue codes for cancellation,
  deletion and operation-specific status rules.

## Transaction API failures

- `400 COMMON-400`: use a UUID goal ID, `DEPOSIT`/`WITHDRAWAL`, and a positive
  whole-rupee JSON integer. PATCH accepts only `amount`; date/type/goal edits
  and unknown fields are rejected.
- `404 TXN-001`: the transaction is absent. Transaction history for an unknown
  goal is an empty page, not an upstream Goal lookup.
- `409 COMMON-409`: a local version conflict is not automatically retried.
  Refresh history and current goal state before deciding on a new edit.
- `503 TXN-002` / `504 TXN-003`: inspect the configured Goal Service address,
  availability and timeout. History and Transaction readiness should still
  work if the Transaction database is healthy.
- A Goal Service 4xx body is passed through unchanged. Its `instance` may
  therefore identify the internal balance-adjustment path rather than the
  public Transaction path.
- `goal_deletion_incomplete`: history was already removed, but final Goal
  deletion failed or its outcome is unknown. If the goal still exists and is
  Cancelled, retry the same cleanup endpoint. If it is already absent, a
  repeat returns `404 GOAL-001`; history must still be empty.

## Cross-service mismatch or unknown outcome

`cross_service_commit_mismatch` is an ERROR event containing `correlationId`,
`goalId`, `transactionId`, `operation`, signed `delta` and `remoteOutcome`.
`confirmed` means a successful Goal response preceded a failed/cancelled local
commit. `unknown` means the remote outcome cannot be established, such as after
a read timeout. A connection/timeout error and local rollback are **not proof
that the remote balance stayed unchanged**.

1. Stop new writes for the affected goal and preserve redacted logs from both
   services. Record the IDs and delta; do not automatically replay the request.
2. Read the Goal snapshot and all pages of transaction history. Compare the
   balance with total deposits minus total withdrawals; also check whether the
   affected transaction and amount actually committed. A commit connection
   failure can leave even the local commit outcome uncertain.
3. Resolve the request outcome using correlated logs and current persisted
   state. If the outcome remains unknown, escalate instead of guessing.
4. Back up affected data and have the maintainer approve a case-specific,
   ORM-backed correction under a maintenance window. Do not create an ordinary
   replacement transaction blindly: it would adjust the goal balance again.
   Status restrictions may also prevent a naive compensating API call.
5. Recheck balance/history consistency and lifecycle state, record the
   correction and only then resume writes.

There is no automatic reconciliation or privileged repair endpoint in Release 1.
The operator must choose and review the actual correction; the steps above are
triage guidance, not a universal recovery script.

## Redis is down

Symptoms: gateway `/ready` returns `{"status":"DEGRADED","checks":{"redis":"DOWN"}}`
(still HTTP 200), the gateway log shows `event=ratelimit_store_unavailable`
at ERROR, and API responses have no `X-RateLimit-*` headers. The access log
shows `"rateLimit":"fail_open"`.

Check the Redis container's status and logs, then `REDIS_HOST`, `REDIS_PORT`
and `REDIS_TIMEOUT_MS`. The host name must resolve through the gateway's
resolver, normally Docker's embedded DNS on the shared network. The limiter
**fails open**: requests continue unlimited while Redis is unreachable.
Successful API responses do not prove Redis or rate limiting is healthy.
Restore Redis connectivity, then confirm `/ready` reports `UP` and responses
carry `X-RateLimit-*` again, instead of treating fail-open as a fix.

During an outage the gateway skips Redis for five seconds after each failure,
so at most one request per five seconds waits for a Redis or DNS timeout. A
successful `/ready` check ends that back-off at once.

## HTTP 429 responses

The limit is 100 requests per client IP in any rolling 60-second window, on
`/api/v1/*` routes only. Honor `Retry-After` and inspect `X-RateLimit-Limit`,
`X-RateLimit-Remaining`, `X-RateLimit-Reset` (seconds until the oldest counted
request leaves the window) and the `COMMON-429` Problem Details body.

Clients behind a shared IP share the limit. With Docker Desktop port
publishing, every host client usually appears as the Docker network's gateway
address, so local tools and browsers share one budget. The access log's
`clientIp` shows the address that was used. Check the trusted-proxy
configuration if it is wrong; never trust arbitrary forwarded headers.
Health, readiness, documentation and the landing page are excluded. The first
30 seconds after gateway startup are neither limited nor counted. Do not
restart the gateway to bypass a limit.

## Gateway returns 404, 502 or 504

- `404` with `"type":"about:blank"` from the gateway: the path is not routed.
  `/internal/*` and metrics endpoints are blocked by design; call them on the
  service's direct port only for local diagnostics.
- `502` "The upstream service is unavailable": the service is stopped, its
  host name does not resolve, or it did not accept a connection within 2
  seconds. Check `GOAL_SERVICE_UPSTREAM` / `TXN_SERVICE_UPSTREAM` and that the
  service shares the gateway's Docker network. Names are re-resolved while the
  gateway runs, so a restarted service recovers without restarting the gateway.
- `504` "did not respond in time": the service accepted the connection but
  sent no response within 10 seconds.
- Transaction `503 TXN-002` and `504 TXN-003` come from the Transaction
  Service about the Goal Service and pass through the gateway unchanged.
- If `/docs/transactions/docs` loads but shows "Failed to load API definition",
  the Transaction Service is not running with `APP_ROOT_PATH=/docs/transactions`.
- Invalid gateway settings stop the container with exit code 64 and a message
  naming the variable; see the [gateway configuration](gateway/README.md#configuration).

## CI pipelines

Each pipeline runs the same Make targets as a developer machine. To
reproduce a failure locally, run that project's `make lint` and
`make coverage`.

- **"Push skipped … KALASH_REGISTRY is not set":** expected until the
  registry is chosen (plan Open Issue 2). Images are still built and checked.
  To push, set the repository variable `KALASH_REGISTRY` (for example
  `ghcr.io/<owner>`) and the secrets `REGISTRY_USERNAME` and
  `REGISTRY_PASSWORD`.
- **"Tag vX.Y.Z does not match … version":** a release tag must equal every
  project's own version: `<version>` in `services/goal-service/pom.xml`,
  `version` in `services/transaction-service/pyproject.toml` (then run
  `uv lock`), and `ARG GATEWAY_VERSION` in `gateway/Dockerfile`. Update
  them, commit, and tag again.
- **"No native SQL" or "No raw SQL" fails:** application code used a native
  query, `JdbcTemplate`, `text()`, `exec_driver_sql` or a raw cursor. Use the
  ORM (D-08); SQL belongs only in migrations.
- **`uv sync --locked` fails:** `pyproject.toml` changed without updating
  the lockfile. Run `uv lock` in `services/transaction-service` and commit
  `uv.lock`.
- **Coverage gate fails:** line coverage dropped below 80%. Add tests; the
  uploaded `*-coverage` artifact shows the uncovered lines.
- **A required check stays "Expected — Waiting":** the branch protection
  rule names a job that did not run. Require the three job names given in
  [CONTRIBUTING](CONTRIBUTING.md#tests-and-quality-gates).
- **Deploy "skipped: set KALASH_REGISTRY, DEPLOY_HOST …":** expected until
  hosting is chosen (plan Open Issue 1). The variables, secrets and the
  `production` environment are listed at the top of
  `.github/workflows/deploy.yml`.
- **Deploy waits for images and times out:** the tag's image pipelines
  failed or did not push. Check the three pipelines for that tag.

## Next steps

Use the [implementation plan](docs/Kalash_Project_Impl_Plan_Opus_v1.0.md) for
phase ownership and the [security policy](SECURITY.md) for private reporting.
Service commands and mismatch triage are documented above; automated recovery
and production operations remain outside Release 1.
