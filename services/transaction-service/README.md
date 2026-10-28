# Transaction Service

The Transaction Service records deposits and withdrawals against goals. It
edits and deletes transactions, serves each goal's transaction history, and
coordinates permanently deleting a cancelled goal and its history. It stores
transactions in its own PostgreSQL database, `transaction_db`. Every balance
change is applied by the Goal Service: the local change is committed only
after the Goal Service accepts it. Python 3.14, FastAPI 0.136.3.

Release 1 is complete. The phase sections in this README record how each
phase was verified. Decisions that affect this service are in the
[ADRs](../../docs/adr/README.md).

## Prerequisites and setup

- Python 3.14 (uv can provision it), uv and PostgreSQL 18.
- An existing `transaction_db` database and a `txn_user` account with access to
  it. Local defaults use `localhost:5433`; the Docker-network port is `5432`.
- The running Goal Service for writes and cancelled-goal deletion. History,
  liveness and database readiness do not require the Goal Service.
- Windows users should use the provided module entry point: it chooses a
  selector event loop compatible with psycopg's async driver.

Run commands from this service directory:

```powershell
uv sync --locked
# Only if .env does not already exist:
Copy-Item .env.example .env
# Edit .env and set TXN_DB_PASSWORD to the database user's local password.
uv run --locked alembic upgrade head
uv run --locked python -m app
```

On Bash, use `cp .env.example .env` instead of `Copy-Item`. Never overwrite an
existing local configuration or commit `.env`. Environment variables override
values in `.env`. A missing/blank password or invalid setting fails startup.

Alembic applies [0001_create_transactions](alembic/versions/0001_create_transactions.py)
using the `op` API. It creates the transaction table, positive-amount and type
CHECK constraints, the primary key, and `(goal_id, created_at DESC)` history
index. No seed rows or cross-database foreign keys are created.

Migrations are explicit, not applied by application startup. Run
`uv run --locked alembic current` to inspect the revision and
`uv run --locked alembic check` to detect metadata drift. The app's readiness
probe tests connectivity, not migration completeness: a reachable but unmigrated
database still needs `alembic upgrade head` before business operations work.
Do not run `downgrade base` on data you need to keep: it deletes all history.

Stop with Ctrl+C (Ctrl+Break is also supported on Windows). The module entry
point uses `timeout_graceful_shutdown=0`, closes the Goal HTTP client and the
database pool, and logs cleanup. The session scope rolls back unfinished work,
including on cancellation. It does not implement a cross-service transaction;
the consistency limitations in the implementation plan still apply.

## Make targets

From this directory, `make help` lists the targets: `format`, `lint`,
`test`, `coverage`, `migrate`, `run`, `clean` and the Compose lifecycle
(`build`, `up`, `down`, `ps`, `logs`). They run uv with the locked
dependency set. `make migrate` then `make run` is the host workflow. Run
`make setup` at the repository root first to create the `.env` and install
the dependencies. See the [scripts guide](../../scripts/README.md).

## Configuration

| Variable | Local default / requirement |
|---|---|
| `APP_ENV` | `local`; also `docker` or `test` |
| `APP_TIMEZONE` | `Asia/Kolkata` (validated IANA timezone) |
| `LOG_LEVEL` | `INFO` |
| `TXN_SERVICE_PORT` | `8000` |
| `TXN_DB_HOST` / `TXN_DB_PORT` | `localhost` / `5433` |
| `TXN_DB_NAME` / `TXN_DB_USER` | `transaction_db` / `txn_user` |
| `TXN_DB_PASSWORD` | Required; never displayed |
| `GOAL_SERVICE_BASE_URL` | `http://localhost:8080` |
| `GOAL_SERVICE_TIMEOUT_SECONDS` | `3`, positive and finite |
| `APP_ROOT_PATH` | Empty for direct access; `/docs/transactions` for a prefix-stripping documentation proxy |

Docker profile uses structured JSON logs and binds on `0.0.0.0`; local/test
profiles bind on `127.0.0.1`. Supply Docker-network hosts explicitly when using
the root environment template. The root template is not automatically loaded
from this service directory.

`APP_ROOT_PATH` is the additional P1 setting needed to express the plan's
gateway-aware FastAPI documentation prefix. The OpenAPI server remains `/`
so Swagger calls public API paths, not paths under the documentation prefix.
The [gateway](../../gateway/README.md) (P4) strips `/docs/transactions` before
forwarding documentation requests, so set `APP_ROOT_PATH=/docs/transactions`
whenever this service runs behind it. P4 verified Swagger UI and
`/docs/transactions/openapi.json` through the gateway with that setting.

## Endpoints

### Business APIs

| Method | Path | Success |
|---|---|---|
| POST | `/api/v1/transactions` | 201 TransactionResponse, with `Location` |
| GET | `/api/v1/transactions?goalId={uuid}&page=0&size=20` | 200 TransactionPage |
| PATCH | `/api/v1/transactions/{transactionId}` | 200 TransactionResponse |
| DELETE | `/api/v1/transactions/{transactionId}` | 204, no body |
| DELETE | `/api/v1/transactions/goals/{goalId}` | 204, no body |

Create example:

```json
{"goalId":"10000000-0000-0000-0000-000000000001","type":"DEPOSIT","amount":5000}
```

Replace the goal ID with one created through the Goal Service. `type` is
`DEPOSIT` or `WITHDRAWAL`; amounts must be positive JSON integers no larger
than `9223372036854775807`. Floats, numeric strings, booleans, nulls and unknown
fields are rejected as `400 COMMON-400`. PATCH accepts only `{"amount":4500}`;
goal, transaction type, creation timestamp and transaction date are immutable.
Dates are assigned from the injected clock in `Asia/Kolkata` by default.

History filters by `goalId`, sorts newest creation first with UUID as a stable
tie-breaker, and defaults to page 0/size 20 (maximum size 100). An unknown goal
with no history returns an empty page; no Goal Service lookup is needed.
History items omit `goalBalance`/`goalStatus`; create/edit include the resulting
snapshot. The explicit LLD endpoint contract takes precedence over its prose
reference to delete response fields: DELETE returns **204 without JSON**.

### Health and documentation

| Endpoint | Purpose |
|---|---|
| `GET /health` | Process-only liveness: `200 {"status":"UP"}` |
| `GET /ready` | ORM session connectivity check: 200 UP or 503 DOWN |
| `GET /docs` | Swagger UI |
| `GET /openapi.json` | OpenAPI schema |
| `GET /metrics` | Prometheus request count and latency |

Readiness checks only `transaction_db`; the Goal Service may be offline.
Database pools are lazy, so an unavailable database does not prevent process
startup or liveness. Connectivity and statement timeouts are bounded.
CORS is not enabled, including on preflight requests.

## Write sequencing and concurrency

Each create/edit/delete stages its ORM change and **flushes before calling the
Goal Service**. This checks local constraints and optimistic versions before a
remote balance change. Only remote success is followed by a local commit.
Remote failures, local errors and request cancellation roll back unfinished
local work. No HTTP retries are performed.

- Create: deposit delta is `+amount`, withdrawal delta is `-amount`.
- Edit: deposit delta is `new - old`, withdrawal delta is `old - new`.
- Delete: reverse the original delta.
- Even a zero-delta edit calls the Goal Service, so status rules are enforced.
- SQLAlchemy `version_id_col` protects edits and deletes. A stale version
  returns `409 COMMON-409`, without reapplying a remote mutation.
- The Goal Service remains the authority for balance/status rules.

Cancelled-goal deletion first reads the goal snapshot, requires `CANCELLED`,
removes its transaction history using bounded ORM batches in one local
transaction, commits, and only then calls the Goal Service's internal DELETE.
If that last call fails, retrying the cleanup is safe: the already-empty
history is harmless. Once the goal is gone, a repeat returns the original
`404 GOAL-001`, as specified by the LLD.

This is **not a distributed transaction**. If the Goal Service applied a change
but the local commit failed, an ERROR `cross_service_commit_mismatch` event
includes correlation ID, goal ID, transaction ID, operation and signed delta.
`remoteOutcome=confirmed` denotes an accepted remote response followed by a
failed/cancelled local commit. `remoteOutcome=unknown` marks a timeout,
interrupted request, invalid mutation response or transport failure where the
remote result cannot be determined. A rollback does not undo a remote commit.
See the [reconciliation guidance](../../TROUBLESHOOTING.md#cross-service-mismatch-or-unknown-outcome);
do not automatically replay requests after timeouts.

## Errors, correlation and logging

- The full LLD error catalogue plus `COMMON-429` is defined in the shared error
  framework. Deliberate API errors return RFC 9457 Problem Details, with
  `errorCode`, `correlationId`, UTC `timestamp` and validation-only `errors`.
- Pydantic request validation returns `400 COMMON-400`; unexpected exceptions
  return a sanitized `500 COMMON-500`. Framework 404/405 errors retain their
  HTTP status and use `about:blank`, without inventing a business error code.
- Goal Service 4xx responses preserve the original body bytes, status,
  content type and `Retry-After` when present. They are not rebuilt or given a
  new timestamp/instance. Timeouts map to `504 TXN-003`; connection failures,
  upstream 5xx and malformed success responses map to `503 TXN-002`.
- Local version conflicts map to `409 COMMON-409`; other persistence failures
  are sanitized `500 COMMON-500`. Missing transactions use `404 TXN-001`.
- Valid `X-Correlation-ID` values (1-128 ASCII letters, digits, `.`, `_`, `-`)
  are echoed and propagated by the shared httpx client. Missing or invalid IDs
  are replaced by UUIDs. Context is isolated per request.
- Local output is coloured only on a TTY with `NO_COLOR` unset. Docker output
  is JSON. Startup summaries include identity, dependency addresses, endpoints
  and timing, never passwords. Error logs contain exception types, not raw
  exception text or request payloads.

## Tests and quality gates

```powershell
uv run --locked ruff check .
uv run --locked ruff format --check .
uv run --locked pytest
```

For formatting fixes, run `uv run --locked ruff check --fix .` followed by
`uv run --locked ruff format .`. The lockfile pins the complete dependency set.
The service targets FastAPI 0.136.3, Pydantic 2, SQLAlchemy 2, psycopg 3 and
Python 3.14. No new runtime dependencies were required for P3.

Unit tests use mocked sessions, fixed clocks and respx, with no running
database, Redis or network calls. Pytest produces a line-coverage report and
fails below **80%**. Tests use importlib mode so feature directories may use
the same test module names without colliding.

### P3 verification

Verified on 2026-10-27:

- `uv run --locked ruff check .` and `uv run --locked ruff format --check .`: passed.
- `uv run --locked pytest`: **181 tests passed**, **99.85% line coverage**.
  One existing upstream Starlette/AnyIO deprecation warning remains.
- `uv run --locked pyright --pythonpath .venv\Scripts\python.exe --pythonversion 3.14 app alembic`:
  passed with 0 errors/warnings using the locally available Pyright tool.
  Pyright is optional tooling, not a newly added project dependency.
- PostgreSQL 18: upgrade, repeated upgrade, downgrade/re-upgrade on an empty
  disposable database, and Alembic metadata drift checks passed.
- Real Python/Goal Service journeys passed for deposits, withdrawals, both edit
  deltas, both deletion reversals, immutable dates/timestamps, paginated history,
  rejected-write rollback, Achieved-state errors and cancelled-goal cleanup.
- Twelve simultaneous edits produced 3 successful commits and 9 explicit
  conflicts in the final acceptance run; persisted transaction amount matched
  the Goal Service balance. Counts vary with scheduling.
- A real Goal timeout rolled back the local insert and logged an unknown remote
  outcome. History/readiness remained available; persisted history survived
  process restart. Docs, metrics, correlation, no CORS and signal cleanup passed.
- Test processes, three temporary containers and the isolated network were
  removed. These checks do not add an integration/e2e suite to this release.

### P6 verification

Verified on 2026-10-28:

- `uv run --locked ruff check .` and `uv run --locked ruff format --check .`: passed.
- `uv run --locked pytest`: **187 tests passed**, **99.85% line coverage**.
- A new router test rejects a lower-case, unknown, null or missing `type`
  and a missing or malformed `goalId` with `COMMON-400`, without touching the
  session or calling the Goal Service.

Integration/e2e suite directories remain placeholders.

## Container

The [Dockerfile](Dockerfile) installs the locked runtime dependencies (no dev
group) with `uv sync --frozen` (uv 0.9.16) into `/opt/venv`, then copies that
environment, `app/` and the Alembic files onto `python:3.14.10-slim`. It runs
as non-root user `kalash` (uid 10001) with `APP_ENV=docker`. The entrypoint
runs `alembic upgrade head` and then `exec python -m app`, so Uvicorn is PID 1
and receives SIGTERM directly. A failed migration stops the container before
the service starts. `docker run ... kalash/transaction-service:0.1.0 alembic
current` runs a one-off command instead. `healthcheck /health` (image) and
`healthcheck /ready` (Compose) probe the service. Labels carry the version,
git SHA, MIT licence and build commit time.

Standalone with its own database, from this directory:

```powershell
Copy-Item .env.example .env   # set TXN_DB_PASSWORD; Bash: cp
docker compose up -d --build --wait
docker compose down           # add -v to delete the transaction-data volume
```

The [compose file](docker-compose.yml) reads only the database name, user,
password, timezone, log level and Goal timeout from `.env`. `GOAL_SERVICE_BASE_URL`
in `.env` points at `localhost` for host runs, so the container uses
`CONTAINER_GOAL_SERVICE_BASE_URL` instead, defaulting to
`http://host.docker.internal:8080`, for example the Goal project stack. Set
`CONTAINER_APP_ROOT_PATH=/docs/transactions` when the gateway project stack
fronts this one. Without a reachable Goal Service the container stays ready,
and writes return 503 `TXN-002`. It publishes ports 8000 and 5433, the same as
the root stack, which sets `APP_ROOT_PATH=/docs/transactions` itself. With
that setting, direct `/docs` on port 8000 keeps working.

See the [root guide](../../README.md),
[contribution rules](../../CONTRIBUTING.md) and
[implementation plan](../../docs/Kalash_Project_Impl_Plan_Opus_v1.0.md).
