# ADR-0009: Publish each service's OpenAPI documentation, also through the gateway

- **Status:** Accepted
- **Date:** 2026-10-28
- **Decision register:** D-18
- **LLD impact:** Deviation: add the documentation routes to LLD §18 and the
  documentation endpoints to §13

## Context

Each service generates its own OpenAPI description: springdoc in the Goal
Service and FastAPI's built-in generator in the Transaction Service.
Developers using the single gateway origin should not need to know the
services' direct ports to read the API, but documentation must never become
a path to unrouted endpoints such as `/internal/*`.

## Decision

- **Direct ports.** The Goal Service serves Swagger UI at `/swagger-ui` and
  OpenAPI at `/v3/api-docs`. The Transaction Service serves `/docs` and
  `/openapi.json`. Internal Goal endpoints are tagged "Internal".
- **Gateway.**
  - `/docs/goals/` and `/docs/transactions/` redirect to each Swagger UI.
  - The gateway forwards only the documentation paths, matched by regular
    expressions, and sets `X-Forwarded-Prefix`.
  - These routes are never rate limited (ADR-0006).
- **Prefixes.**
  - The Goal Service honours `X-Forwarded-Prefix` (Spring
    `forward-headers-strategy: framework`) for its Swagger configuration.
  - The Transaction Service uses `APP_ROOT_PATH=/docs/transactions` in the
    stack, and direct `/docs` keeps working.
  - The OpenAPI server URL stays `/`, so "Try it out" calls the real
    `/api/v1/...` paths through the gateway.

## Consequences

- Both Swagger UIs work at `http://localhost/docs/goals/` and
  `http://localhost/docs/transactions/`, and on the direct ports.
- The Transaction Service needs `APP_ROOT_PATH` set when it is behind the
  gateway; the root Compose file does this.
- Documentation is public with no authentication. The policy for any
  non-local deployment is plan Open Issue 10.

## References

- `gateway/conf/conf.d/docs.conf`, `gateway/conf/snippets/proxy.conf`
- `services/goal-service/.../common/config/GoalApiDocumentation.java`
- `services/transaction-service/app/main.py` (`root_path`)
