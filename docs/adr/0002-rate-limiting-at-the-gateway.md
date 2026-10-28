# ADR-0002: Rate limit at the gateway with OpenResty, Lua and Redis

- **Status:** Accepted
- **Date:** 2026-10-28
- **Decision register:** D-09 (with D-15 for the client IP)
- **LLD impact:** Deviation from LLD §5 and §27: Redis is a new component and
  the `nginx` gateway image becomes OpenResty

## Context

Release 1 must limit each client to 100 requests per rolling minute. The
LLD's gateway is plain Nginx, whose `limit_req` module uses a leaky bucket
kept in each Nginx instance's memory. That cannot express "100 in any
rolling 60 seconds", does not survive a reload exactly, and would not be
shared if the gateway were scaled out. Limiting inside each service would
duplicate the logic in Java and Python and count traffic per service, not
per client.

## Decision

- The gateway is OpenResty 1.31.1.1 (Nginx with LuaJIT), so the limiter is
  a small Lua module in `access_by_lua` that runs before proxying.
- Counters live in Redis 8.8, shared by every gateway worker and instance.
  Redis runs without persistence (`--save "" --appendonly no`) and with
  `--maxmemory 64mb --maxmemory-policy volatile-ttl`, because losing the
  counters only resets the window.
- The client key is `$remote_addr`. The `real_ip` module accepts
  `X-Forwarded-For` only from the proxies listed in `TRUSTED_PROXIES`
  (empty by default), so clients cannot spoof their address (D-15).
- Limits are configured by `RATE_LIMIT_REQUESTS`,
  `RATE_LIMIT_WINDOW_SECONDS` and `RATE_LIMIT_WARMUP_SECONDS`, validated
  before start-up.

The algorithm, warm-up, failure mode, routes and response are separate
decisions: ADR-0003 to ADR-0007.

## Consequences

- One more container (`redis`, not published) in the root and gateway stacks.
- Services stay free of rate-limit code; the limit applies once per client
  across both APIs.
- The gateway's Lua is unit tested with busted against a fake `ngx` and a
  Redis double that runs the real script (80 tests, luacheck clean).
- Clients behind a shared NAT share one limit. That is acceptable for the
  local demonstration and documented in `SECURITY.md`.

## References

- `gateway/lua/kalash/`, `gateway/conf/`, `gateway/docker-compose.yml`
- Plan Section 5.5 (P4 tasks and evidence)
