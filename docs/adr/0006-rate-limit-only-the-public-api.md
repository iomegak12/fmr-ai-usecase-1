# ADR-0006: Rate limit only `/api/v1/*`

- **Status:** Accepted
- **Date:** 2026-10-28
- **Decision register:** D-13
- **LLD impact:** New behaviour; add it to the LLD's gateway routing section
  (§18)

## Context

The gateway also serves health and readiness checks, Swagger UI and OpenAPI
documents, and a static landing page. Health checks are polled continuously
by Docker and operators, and Swagger UI loads several assets per page view.
Counting those would let monitoring or reading the documentation consume a
client's API allowance, and a limited health check could make orchestration
restart a healthy gateway.

## Decision

- Only the locations for `/api/v1/goals`, `/api/v1/transactions` and the
  `/api/v1/` catch-all run the limiter.
- `/`, `/health`, `/ready`, `/health/{goals,transactions}`,
  `/ready/{goals,transactions}`, `/docs/goals/` and `/docs/transactions/`
  are never limited or counted.
- `/internal/*` and metrics paths are not routed at all (404).

## Consequences

- A rate-limited client can still see documentation, health and the landing
  page, which was verified after a client received 429s.
- `gateway/spec/routes_spec.lua` parses the route configuration and fails
  if any location other than `/api/v1/*` runs the limiter, or if
  `/internal/` or a metrics path is forwarded. Route changes must keep it
  passing.

## References

- `gateway/conf/conf.d/routes.conf`, `docs.conf`, `health.conf`
- `gateway/spec/routes_spec.lua`
