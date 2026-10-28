# ADR-0007: Reject with 429 Problem Details `COMMON-429` and rate-limit headers

- **Status:** Accepted
- **Date:** 2026-10-28
- **Decision register:** D-14
- **LLD impact:** Deviation: add `COMMON-429` to the error catalogue in LLD
  §21.2

## Context

Every other error in Kalash is RFC 9457 Problem Details with an `errorCode`,
`correlationId` and `timestamp`, and the web app displays `title` and
`detail` as they are. A rate-limit rejection in a different format would need
special handling in every client, and clients need to know when they may
retry.

## Decision

- A rejected request gets HTTP 429 with `Content-Type: application/problem+json`
  and `Cache-Control: no-store`:

  ```json
  {
    "type": "urn:kalash:error:COMMON-429",
    "title": "Too many requests, please retry later",
    "status": 429,
    "detail": "Limit of 100 requests per 60 seconds reached. Retry after 12 seconds.",
    "instance": "/api/v1/goals",
    "errorCode": "COMMON-429",
    "correlationId": "...",
    "timestamp": "2026-10-28T09:00:00.000Z"
  }
  ```

- Headers on rejections: `Retry-After` (seconds), `X-RateLimit-Limit`,
  `X-RateLimit-Remaining` (0) and `X-RateLimit-Reset`.
- Allowed, counted requests also carry the three `X-RateLimit-*` headers.
- `X-RateLimit-Reset` is the number of seconds until the oldest counted
  request leaves the window: the same unit as `Retry-After`, not a Unix
  timestamp.
- `COMMON-429` is also in the Goal Service's `ErrorCode` enum, so its
  OpenAPI documentation lists it, although only the gateway produces it.

## Consequences

- Clients handle rate limiting like any other error and can schedule a
  retry from either header.
- Warm-up and fail-open requests carry no `X-RateLimit-*` headers, because
  they were not counted (ADR-0004, ADR-0005).
- The LLD's error catalogue needs the new row.

## References

- `gateway/lua/kalash/problem.lua`, `ratelimit.lua`
- `gateway/spec/problem_spec.lua`, `ratelimit_spec.lua`
- `services/goal-service/.../common/error/ErrorCode.java`
