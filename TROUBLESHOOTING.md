# Troubleshooting

## Phase 1 status

Both backend foundations now run locally; use the
[Goal Service](services/goal-service/README.md) and
[Transaction Service](services/transaction-service/README.md) guides.
Business features, migrations, gateway, Docker Compose and Make targets remain
in later phases. Redis and rate-limiting guidance below describes planned
behavior, not a running gateway.

## Service startup and runtime versions

- Goal Service requires Java 25, not Java 21. Set `JAVA_HOME` and `PATH` only
  for the shell running the build, or use the JDK 25 Docker approach in the
  service guide. Do not change a shared machine's JDK for other projects.
- Goal Service does not automatically read `.env`; export its database and
  profile settings before launching Spring.
- Transaction Service uses Python 3.14 via `uv sync --locked`. Run it from its
  own directory with `uv run --locked python -m app`, so its `.env` is loaded
  and the correct Windows async loop is selected.
- The root `.env.example` is for the future full-stack Docker network. Its
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

Planned host ports are gateway `80`, Goal Service `8080`, Transaction Service
`8000`, Goal database `5432` and Transaction database `5433`.

- Windows PowerShell: inspect listeners with
  `Get-NetTCPConnection -State Listen -LocalPort 80,8080,8000,5432,5433`
  and identify the returned owning PID with `Get-Process -Id <PID>`.
- Linux: inspect listeners with `ss -ltnp`.
- macOS: inspect listeners with `lsof -nP -iTCP -sTCP:LISTEN`.
- Stop only a process you own and have identified, or adjust the applicable
  host-port mapping once Compose configuration exists. Do not indiscriminately
  terminate shared processes.

Both databases use port `5432` inside the Docker network; host port `5433` for
the Transaction database must not become its container-side connection port.

## Docker is not running

Once container tooling is added, use `docker info` to confirm daemon access and
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

Makefiles and matching `.sh`/`.ps1` scripts will be added in P7. A missing
Makefile in Phase 1 is expected, not a broken setup.

## Migration failures

After P1-P3 add database support:

1. Read the first migration error in the affected service's redacted logs.
2. Check database availability and the relevant host, port, database name,
   username and locally configured password.
3. Use Docker service names inside containers; use `localhost` and published
   host ports for host-run services.
4. Goal Service migrations use Flyway on startup; Transaction Service migrations
   use Alembic. Inspect migration history before changing a migration.
5. Do not edit an already-applied migration, reset a shared database or delete
   volumes as a shortcut. Back up any data that must be preserved and escalate
   conflicting migration history to the maintainer.

The root environment example targets the Docker network. It is not a ready-made
host-run configuration.

## Redis is down

After P4-P5 introduce Redis and the gateway, check Redis container status and
logs, then check `REDIS_HOST`, `REDIS_PORT` and `REDIS_TIMEOUT_MS`.
The planned limiter **fails open**: requests continue and an ERROR is logged;
gateway readiness reports degraded. Successful API responses do not prove
Redis or rate limiting is healthy. Restore Redis connectivity and verify
readiness and limiter behavior instead of treating fail-open as a fix.

## HTTP 429 responses

The planned limit is 100 requests per client IP in any rolling 60-second window,
on `/api/v1/*` routes only. Honor `Retry-After` and inspect
`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` and the
`COMMON-429` Problem Details body.

Clients behind a shared IP share the limit. Check trusted-proxy configuration
if the wrong IP is used; never trust arbitrary forwarded headers. Health,
readiness, documentation and the landing page are excluded. The first 30
seconds after gateway startup are neither limited nor counted. Do not restart
the gateway to bypass a limit.

## Next steps

Use the [implementation plan](docs/Kalash_Project_Impl_Plan_Opus_v1.0.md) for
phase ownership and the [security policy](SECURITY.md) for private reporting.
Concrete service commands and a reviewed cross-service mismatch recovery
procedure will be documented when those features are implemented.
