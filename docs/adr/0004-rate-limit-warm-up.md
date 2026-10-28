# ADR-0004: Neither limit nor count requests for 30 seconds after start-up

- **Status:** Accepted
- **Date:** 2026-10-28
- **Decision register:** D-11
- **LLD impact:** New behaviour; add it to the LLD's rate-limiting section

## Context

Immediately after the gateway starts, clients that were waiting reconnect,
retry and reload at once, and Redis connections are still being
established. Counting that burst would reject legitimate catch-up traffic.
Counting it but not enforcing would leave a full window charged against
every client as soon as enforcement starts.

## Decision

- `init_worker_by_lua` records the gateway start time once, in the shared
  dictionary `kalash_gateway` (`add`, so only the first worker sets it).
  Worker reloads keep the original start.
- For `RATE_LIMIT_WARMUP_SECONDS` (default 30, `0` disables) after that
  time, `/api/v1/*` requests skip the limiter entirely: no Redis call, no
  counting and no `X-RateLimit-*` headers.
- Enforcement starts at exactly start + warm-up, from an empty window.

## Consequences

- During warm-up a client can exceed 100 requests per minute. In testing,
  121 requests in warm-up all passed and left no Redis keys.
- A gateway restart opens a new warm-up window. This is a fairness control,
  not a security boundary, as `SECURITY.md` states.
- The start-up log line `event=gateway_started` records `warmupEndsAt`.

## References

- `gateway/lua/kalash/warmup.lua`, `gateway.lua`
- `gateway/spec/warmup_spec.lua`, `ratelimit_spec.lua`
