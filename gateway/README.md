# API Gateway

**Phase 0 scaffold only; not runnable.**

Planned stack: OpenResty, Lua and Redis. P4 implements public API routing,
documentation routing, internal-route blocking, health/readiness and a static
landing page. The React frontend is not part of this scope.

The planned per-IP sliding-window limiter allows 100 requests in any rolling
60 seconds on `/api/v1/*`, skips limiting and counting for the first 30 seconds
after startup, and fails open with ERROR logging if Redis is unavailable.
Health, readiness, documentation and landing-page routes are excluded.

`conf` holds gateway configuration, `lua/kalash` limiter modules, `html` the
landing page and `spec` unit tests. No implementation files exist yet.
Standalone configuration, Docker/Compose, Make targets and run/test commands
will be documented when implemented.

Planned host port: `80`. Tests will use busted with fake Redis, clocks and
`ngx`; luacheck provides linting and luacov reports coverage without a numeric
gate.

See the [root guide](../README.md), [contribution rules](../CONTRIBUTING.md)
and [implementation plan](../docs/Kalash_Project_Impl_Plan_Opus_v1.0.md).
