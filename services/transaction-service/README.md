# Transaction Service

**Phase 1 foundations implemented.** Deposits, withdrawals, transaction history,
Goal Service business calls and cancelled-goal deletion arrive in P3. No
business endpoints or database migrations exist yet.

## Prerequisites and setup

- Python 3.14 (uv can provision it), uv and PostgreSQL 18.
- An existing `transaction_db` database and a `txn_user` account with access to
  it. Local defaults use `localhost:5433`; the Docker-network port is `5432`.
- Windows users should use the provided module entry point: it chooses a
  selector event loop compatible with psycopg's async driver.

Run commands from this service directory:

```powershell
uv sync --locked
# Only if .env does not already exist:
Copy-Item .env.example .env
# Edit .env and set TXN_DB_PASSWORD to the database user's local password.
uv run --locked python -m app
```

On Bash, use `cp .env.example .env` instead of `Copy-Item`. Never overwrite an
existing local configuration or commit `.env`. Environment variables override
values in `.env`. A missing/blank password or invalid setting fails startup.

Stop with Ctrl+C (Ctrl+Break is also supported on Windows). The module entry
point uses `timeout_graceful_shutdown=0`, closes the Goal HTTP client and the
database pool, and logs cleanup. The session scope rolls back unfinished work,
including on cancellation. It does not implement a cross-service transaction;
the consistency limitations in the implementation plan still apply.

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
The gateway must strip `/docs/transactions` before forwarding documentation
requests; gateway implementation is P4.

## Endpoints

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

## Errors, correlation and logging

- The full LLD error catalogue plus `COMMON-429` is defined in the shared error
  framework. Deliberate API errors return RFC 9457 Problem Details, with
  `errorCode`, `correlationId`, UTC `timestamp` and validation-only `errors`.
- Pydantic request validation returns `400 COMMON-400`; unexpected exceptions
  return a sanitized `500 COMMON-500`. Framework 404/405 errors retain their
  HTTP status and use `about:blank`, without inventing a business error code.
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
Python 3.14; Alembic is installed for P3 migrations.

Unit tests use mocked sessions, fixed clocks and respx, with no running
database, Redis or network calls. Pytest produces a line-coverage report and
fails below **80%**. The separate manual P1 acceptance check verified a real
PostgreSQL 18 connection, database-down readiness, direct docs/metrics, absent
CORS headers and Windows console-signal cleanup.

Compose files, containers, Make targets and CI are deferred to their planned
phases. Integration/e2e suite directories remain placeholders.

See the [root guide](../../README.md),
[contribution rules](../../CONTRIBUTING.md) and
[implementation plan](../../docs/Kalash_Project_Impl_Plan_Opus_v1.0.md).
