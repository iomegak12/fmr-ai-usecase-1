# ADR-0005: Fail open when Redis is unavailable

- **Status:** Accepted
- **Date:** 2026-10-28
- **Decision register:** D-12
- **LLD impact:** New behaviour; add it to the LLD's rate-limiting section

## Context

The limiter depends on Redis, but the business APIs do not. If Redis is
stopped, slow or unreachable, the gateway must either reject every API
request (fail closed) or forward them unlimited (fail open). For a savings
planner used locally, losing the whole product because a fairness control
is down is the worse outcome.

## Decision

- Any Redis error or timeout forwards the request without limiting and
  logs ERROR `event=ratelimit_store_unavailable outcome=fail_open` with the
  client IP and correlation ID.
- Redis calls use short timeouts (`REDIS_TIMEOUT_MS`, default 100 ms) and a
  keep-alive pool.
- After a failure, a shared 5-second back-off stops other requests from
  waiting on Redis. When it expires, one request probes Redis; success ends
  the back-off.
- The gateway's `/ready` reports `{"status":"DEGRADED","checks":{"redis":"DOWN"}}`
  with HTTP 200 while Redis is down, so orchestration does not restart a
  gateway that is still serving traffic.

## Consequences

- An outage removes the rate limit until Redis returns. Every affected
  request is logged at ERROR, so the gap is visible.
- In testing, an outage slowed at most one request per back-off interval
  (1 of 60), instead of every request waiting on DNS or connection timeouts.
- Fail-open requests carry no `X-RateLimit-*` headers, because nothing was
  counted.

## References

- `gateway/lua/kalash/store.lua`, `ratelimit.lua`, `gateway.lua`
- `gateway/spec/store_spec.lua`, `ratelimit_spec.lua`, `gateway_spec.lua`
- `TROUBLESHOOTING.md`, "Redis is down"
