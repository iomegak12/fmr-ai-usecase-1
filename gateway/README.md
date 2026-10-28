# API Gateway

OpenResty 1.31.1.1 (Alpine) with a Lua
sliding-window rate limiter backed by Redis. It is the single public origin
for both services: API routing, documentation and health pass-through,
internal-route blocking and a static landing page. It runs as a non-root,
labelled image, in the root stack (`make up`) or in its own compose project.

Design references: LLD §18, plan Section 5.5 and decisions D-09 to D-15,
D-18 and D-29 in the [implementation plan](../docs/Kalash_Project_Impl_Plan_Opus_v1.0.md).
The rate-limiting decisions are explained in
[ADR-0002 to ADR-0007](../docs/adr/README.md).

## Routes

| Path | Behaviour | Rate limited |
|---|---|---|
| `/` | Landing page: API paths, docs and health links, version | No |
| `/api/v1/goals`, `/api/v1/goals/*` | Goal Service, 10-second read timeout | Yes |
| `/api/v1/transactions`, `/api/v1/transactions/*` | Transaction Service, 10-second read timeout | Yes |
| any other `/api/v1/*` | 404 Problem Details | Yes |
| `/docs/goals/` | Redirects to Goal Swagger UI; `/docs/goals/swagger-ui/**` and `/docs/goals/v3/api-docs/**` only | No |
| `/docs/transactions/` | Redirects to Transaction Swagger UI; `/docs/transactions/docs` and `/docs/transactions/openapi.json` only | No |
| `/health` | Gateway liveness: `{"status":"UP"}` | No |
| `/ready` | Gateway readiness: `UP`, or `DEGRADED` with HTTP 200 when Redis is unreachable | No |
| `/health/goals`, `/ready/goals` | Goal Service `/health`, `/ready` | No |
| `/health/transactions`, `/ready/transactions` | Transaction Service `/health`, `/ready` | No |
| `/internal/*` | 404 Problem Details; never forwarded | No |
| anything else, including metrics | 404 Problem Details | No |

Every response carries `X-Correlation-ID`. A client's value is reused when the
services would accept it (1–128 letters, digits, `.`, `_` or `-`). Otherwise
the gateway generates one. Upstream copies of the header are replaced, so
the gateway and both services log the same ID. No CORS headers are added (D-19).

Forwarded headers are set by the gateway, not taken from the client.
`X-Forwarded-Host`, `-Proto` and `-For` describe the gateway's own view of the
request. `X-Forwarded-Prefix` is sent only on Goal documentation routes.
Client-supplied `Forwarded`, `X-Forwarded-Port` and `X-Forwarded-Ssl` headers
are removed.

**Documentation prerequisites.** The gateway strips the `/docs/...` prefix
before forwarding. The Goal Service then builds its Swagger URLs from
`X-Forwarded-Prefix` with no extra setting. The Transaction Service must run
with `APP_ROOT_PATH=/docs/transactions`, so that its Swagger page requests the
schema through the gateway. Both specifications advertise server `/`, so
"Try it out" calls the public, rate-limited API routes.

## Rate limiting

| Rule | Behaviour |
|---|---|
| Scope | `/api/v1/*` only (D-13) |
| Key | Client IP, `$remote_addr` after `real_ip` processing (D-15) |
| Algorithm | Sliding-window log: one Redis sorted set per IP, updated by one atomic Lua script (D-10). Entries older than the window are removed, the rest are counted, and the request is added only when under the limit. The key expires one window after its newest entry |
| Limit | `RATE_LIMIT_REQUESTS` (100) in any rolling `RATE_LIMIT_WINDOW_SECONDS` (60) |
| Warm-up | For `RATE_LIMIT_WARMUP_SECONDS` (30) after the container starts, requests are neither limited nor counted (D-11). A configuration reload does not restart warm-up; a container restart does |
| Rejection | HTTP 429, `application/problem+json`, `errorCode` `COMMON-429`, `Retry-After` (D-14) |
| Headers | Every counted request, allowed or rejected, gets `X-RateLimit-Limit`, `X-RateLimit-Remaining` and `X-RateLimit-Reset`. Reset is the number of seconds until the oldest counted request leaves the window, the same unit as `Retry-After`. Warm-up and fail-open requests are not counted and get no `X-RateLimit-*` headers |
| Redis down | Fail open (D-12): the request is forwarded, and ERROR `event=ratelimit_store_unavailable` is logged for every affected request. `/ready` reports `DEGRADED` |

Redis is called with `REDIS_TIMEOUT_MS` connect, send and read timeouts and
pooled keepalive connections. After a failure, every worker skips Redis for
five seconds. When that ends, a single request probes Redis again while the
others keep failing open, so an outage slows at most one request per five
seconds. That request may wait up to the 2-second DNS timeout when the Redis
container is gone. Without this back-off, every request paid that timeout.
A successful `/ready` check ends the back-off immediately.

Memory (risk R-04): an active IP holds at most `RATE_LIMIT_REQUESTS` members
of about 45 bytes each, roughly 10 KB per IP at the default limit including
sorted-set overhead. Keys of idle IPs expire after one window.

**Client IP behind Docker.** With Docker Desktop port publishing, host
clients usually reach the gateway from the Docker network's gateway address,
so they share one limit. `TRUSTED_PROXIES` changes the client IP only for
requests arriving from a listed proxy, which then supplies the real client in
`X-Forwarded-For`. Never list addresses that untrusted clients can send from.

## Configuration

Read at container start. [`.env.example`](.env.example) is the standalone
template; the root [`.env.example`](../.env.example) carries the same
variables for the full stack.

| Variable | Default | Notes |
|---|---|---|
| `GOAL_SERVICE_UPSTREAM` | `goal-service:8080` | `host:port`; re-resolved while running |
| `TXN_SERVICE_UPSTREAM` | `transaction-service:8000` | `host:port`; re-resolved while running |
| `REDIS_HOST` / `REDIS_PORT` | `redis` / `6379` | |
| `REDIS_TIMEOUT_MS` | `100` | 1–10000 |
| `RATE_LIMIT_REQUESTS` | `100` | 1–100000 |
| `RATE_LIMIT_WINDOW_SECONDS` | `60` | 1–86400 |
| `RATE_LIMIT_WARMUP_SECONDS` | `30` | 0–86400; `0` disables warm-up |
| `TRUSTED_PROXIES` | empty | Comma-separated IPs or CIDR ranges |
| `GATEWAY_RESOLVER` | container's first nameserver | DNS server for upstream and Redis names (Docker's `127.0.0.11` on a Compose network) |
| `NO_COLOR` | unset | Disables banner colours (also off without a TTY) |

Invalid values stop the container before nginx starts, with a message naming
the variable (exit code 64). The entrypoint validates the upstreams, resolver
and trusted proxies itself. The limiter settings are validated by the same
`kalash.config` module that nginx loads.

## Make targets

From this directory, `make help` lists the targets: `lint`, `test`,
`coverage`, `clean` and the Compose lifecycle (`build`, `up`, `down`, `ps`,
`logs`). The code-quality targets build the Dockerfile's `test` stage and
run luacheck, busted or luacov in it against the working tree, with no
network. There is no Lua formatter, so there is no `format` target. See the
[scripts guide](../scripts/README.md).

## Build and run

Docker is the supported runtime. In the full stack, the root
[`make up`](../README.md#5-quick-start-full-stack-in-docker) starts the gateway
last, after both services report ready and Redis is healthy.

Standalone with its own Redis, from this directory:

```powershell
Copy-Item .env.example .env   # optional; Bash: cp
docker compose up -d --build --wait
docker compose down
```

The [compose file](docker-compose.yml) forwards by default to services
published on the Docker host (`host.docker.internal:8080` and `:8000`), for
example the Goal and Transaction project stacks. P5 verified that chain on
Docker Desktop. Until an upstream answers, its routes return 502. For
`/docs/transactions/`, run the Transaction stack with
`CONTAINER_APP_ROOT_PATH=/docs/transactions`. On Linux, nginx resolves upstream
names through DNS only, so set `GOAL_SERVICE_UPSTREAM` and
`TXN_SERVICE_UPSTREAM` to the host's bridge address (for example
`172.17.0.1:8080`). Redis is not published.

The image runs as non-root user `kalash` (uid 10001), master process
included. Docker allows unprivileged containers to bind port 80, because it
sets `net.ipv4.ip_unprivileged_port_start=0`. The user owns only the rendered
configuration, the pid directory and the nginx temp directory. Labels carry
the version, git SHA, MIT licence and build commit time.

The container prints a start-up banner with the version, routes, upstreams,
limiter settings, warm-up end time, Redis target and trusted proxies. It never
prints secrets. Then it logs `event=gateway_started` with the same warm-up end.

`docker stop` sends SIGQUIT (`nginx -s quit` semantics). In-flight requests
finish within `worker_shutdown_timeout` (5 seconds), each worker logs
`event=gateway_worker_stopped` as its Redis keepalive pool is released, and
the container exits with code 0.

## Responses produced by the gateway

| Status | When | Body |
|---|---|---|
| 429 | Over the rate limit | Problem Details, `type` `urn:kalash:error:COMMON-429`, `errorCode` `COMMON-429` |
| 404 | `/internal/*`, unknown or unrouted paths | Problem Details, `type` `about:blank` |
| 502 | Upstream unreachable, or the connection could not be established in 2 seconds | Problem Details, `type` `about:blank` |
| 504 | Upstream accepted the connection but sent no response within 10 seconds | Problem Details, `type` `about:blank` |

Problem Details follow the services' shape (LLD §21.1): `type`, `title`,
`status`, `detail`, `instance`, `errorCode` (catalogue errors only),
`correlationId` and a UTC `timestamp`. Upstream 4xx/5xx responses, such as
`TXN-002` or `TXN-003`, are passed through unchanged.

## Logging

The access log goes to stdout as one JSON object per request, with these
fields: `timestamp`, `level` (from the status), `service`, `message`,
`correlationId`, `clientIp`, `method`, `path`, `status`, `durationSeconds`,
`upstream`, `upstreamStatus`, `upstreamConnectSeconds`, `rateLimit` (`skipped`,
`warmup`, `allowed`, `rejected` or `fail_open`), `rateLimitRemaining`,
`bytesSent` and `userAgent`.

Gateway events go to the nginx error log on stderr as `key=value` text:

| Event | Level |
|---|---|
| `gateway_started` | NOTICE (once per start) |
| `ratelimit_rejected` | WARN |
| `ratelimit_store_unavailable` | ERROR |
| `readiness_degraded` | WARN |
| `upstream_unavailable` | ERROR |
| `gateway_worker_stopped` | NOTICE (per worker) |

## Tests

Unit tests use busted 2.3.0 with test doubles for `ngx`, the clock and Redis.
The Redis double executes the real limiter script against an in-memory sorted
set, so the sliding-window logic itself is tested. luacheck 1.2.0 lints
modules and specs. luacov 0.17.0 reports coverage with no numeric gate (D-23).
A route-table spec reads `conf/conf.d` and fails if any non-`/api/v1/`
location runs the limiter, or if `/internal/` or a metrics path is forwarded.

```powershell
docker build --target test -t kalash/gateway-test gateway
docker run --rm -v "${PWD}/gateway:/gateway" kalash/gateway-test
```

On Bash: `docker run --rm -v "$PWD/gateway:/gateway" kalash/gateway-test`
(on Git Bash for Windows, prefix with `MSYS_NO_PATHCONV=1`). Without the
volume, the image tests the sources copied in at build time. Coverage output
(`luacov.*.out`) is ignored by Git.

## Layout

| Path | Contents |
|---|---|
| `conf/nginx.conf` | Main configuration and explicit includes |
| `conf/conf.d/` | `logging`, `real_ip`, `upstreams.conf.template`, `lua`, `server`, `routes`, `docs`, `health` |
| `conf/snippets/proxy.conf` | Shared upstream headers and timeouts |
| `lua/kalash/` | `config`, `warmup`, `ratelimit_script`, `store`, `ratelimit`, `problem`, `gateway` (LuaDoc on every module) |
| `html/index.html` | Landing page; the version is stamped at image build |
| `spec/` | busted specs and `support/` doubles |
| `docker-entrypoint.sh` | Validation, config rendering into `conf/generated/`, banner |
| `Dockerfile` | `test` stage (Lua tools) and non-root `runtime` stage |
| `docker-compose.yml` | Standalone project: gateway and Redis |

## P4 verification

Verified on 2026-10-27 with OpenResty 1.31.1.1 and Redis 8.8.4:

- luacheck: 0 warnings in 17 files. busted: 80 tests passed. luacov: 99.65%
  line coverage. The one uncounted line is the module that returns the Redis
  script as a string; the script itself runs in every limiter spec.
- `openresty -t` passes on the rendered configuration. Invalid upstreams,
  trusted proxies and limiter values stop start-up with exit code 64 before
  the banner.
- Warm-up: 121 API requests in the first 30 seconds all returned 200
  (`rateLimit: warmup`), and Redis held no keys. After warm-up, requests
  1–100 returned 200 and request 101 returned 429 with `COMMON-429`,
  `Retry-After: 57` and all `X-RateLimit-*` headers.
- While that client was blocked, `/health`, `/ready`, the pass-through health
  routes, documentation and the landing page still returned 200.
- 150 concurrent requests from one new IP across 16 workers: exactly 100
  allowed, 50 rejected, 100 Redis entries and 50 WARN events.
- Redis stopped: API requests from a blocked client succeeded, every one
  logged ERROR, and `/ready` returned `DEGRADED` with HTTP 200. With the
  shared back-off, 1 of 60 requests waited for the DNS timeout; the rest
  added no measurable delay. After Redis restarted, `/ready` returned `UP`
  and counting resumed.
- `/internal/*`, dot-segment and percent-encoded traversal attempts, metrics
  paths and API paths under `/docs/*` all returned 404. Spoofed forwarded
  headers were replaced or removed.
- Real services (Goal on Java 25, Transaction on Python 3.14, PostgreSQL 18):
  both Swagger UIs and specs loaded through `/docs/goals/` and
  `/docs/transactions/`. Health pass-through worked. A goal was created and a
  deposit recorded through the gateway, and the client's correlation ID
  appeared in the gateway, Transaction and Goal logs. `/internal/v1/goals/{id}`
  returned 404 through the gateway and 200 directly.
- A slow upstream returned a 504 Problem after 10 seconds; a stopped upstream
  returned a 502 Problem. Rate-limit and correlation headers survived both
  error pages. The Docker health check reported healthy. `docker stop`
  completed in about 0.5 seconds with exit code 0.

Temporary containers, volumes and the test network were removed.

## Known limitations

- Every container restart opens a new 30-second unlimited window (risk R-02).
  The banner and `gateway_started` show when it ends.
- Fail-open removes protection while Redis is down (R-03). Watch for
  `ratelimit_store_unavailable` and `/ready` = `DEGRADED`.
- The limiter is a fairness control, not a security perimeter. There is no
  authentication, and Swagger is reachable through the gateway (Open Issue 10).
- `X-Forwarded-Host` reflects the client's `Host` header, so Spring builds
  documentation links from it. This is acceptable only for the local demonstration.
- With Docker Desktop port publishing, all host clients share one client IP
  and therefore one rate limit (see "Client IP behind Docker").
