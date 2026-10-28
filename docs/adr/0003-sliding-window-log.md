# ADR-0003: Use a sliding-window log in one atomic Redis script

- **Status:** Accepted
- **Date:** 2026-10-28
- **Decision register:** D-10
- **LLD impact:** New design detail; no LLD section to change beyond the
  rate-limiting addition in ADR-0002

## Context

"100 requests per minute" can be implemented as a fixed window (resets on
the minute), a sliding-window approximation, a token bucket or an exact
sliding-window log. A fixed window lets a client send 200 requests across a
window boundary. Approximations can over- or under-count. With several
gateway workers handling one client concurrently, a read-then-write sequence
in Lua would let concurrent requests all see "99" and all pass.

## Decision

- Each client IP has one Redis sorted set, `kalash:ratelimit:<ip>`. Every
  counted request is a member scored with its arrival time in milliseconds.
  The member is `<now_ms>:<request_id>`, so requests in the same millisecond
  stay distinct.
- One Lua script, run with `EVALSHA` (falling back to `EVAL` after
  `NOSCRIPT`), does everything atomically:
  1. remove members older than the window (`ZREMRANGEBYSCORE`);
  2. count the rest (`ZCARD`);
  3. if the count is below the limit, add this request and refresh the key
     expiry to one window (`PEXPIRE`);
  4. return allowed or rejected, the remaining capacity, and when the oldest
     counted request leaves the window.
- Rejected requests are not added, so a client that keeps retrying does not
  extend its own lockout.

## Consequences

- The limit is exact: in testing, 150 concurrent requests from one IP across
  16 workers produced exactly 100 allowed and 50 rejected, with 100 Redis
  members.
- Memory grows with the limit: at most 100 members per active client, each
  expiring with its key after one idle window.
- `X-RateLimit-Reset` and `Retry-After` are derived from the oldest counted
  request, so they report when capacity actually returns.

## References

- `gateway/lua/kalash/ratelimit_script.lua`, `store.lua`, `ratelimit.lua`
- `gateway/spec/ratelimit_script_spec.lua`, `ratelimit_spec.lua`
