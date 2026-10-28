# Architecture Decision Records

These records explain the Release 1 decisions that change or extend the
[LLD](../Kalash_LLD_v1.0.md). Each one has a status, context, decision,
consequences and the matching LLD impact. The full decision register,
including decisions that need no record, is Section 3 of the
[implementation plan](../Kalash_Project_Impl_Plan_Opus_v1.0.md#3-decision-register).
The LLD changes these decisions require are listed in
[LLD 1.1 updates](../Kalash_LLD_v1.1_Updates.md).

| ADR | Decision | Register | Status |
|---|---|---|---|
| [0001](0001-uv-for-python-packaging.md) | Use uv with a lockfile for Python packaging | D-04 | Accepted |
| [0002](0002-rate-limiting-at-the-gateway.md) | Rate limit at the gateway with OpenResty, Lua and Redis | D-09 | Accepted |
| [0003](0003-sliding-window-log.md) | Use a sliding-window log in one atomic Redis script | D-10 | Accepted |
| [0004](0004-rate-limit-warm-up.md) | Neither limit nor count requests for 30 seconds after start-up | D-11 | Accepted |
| [0005](0005-fail-open-when-redis-is-down.md) | Fail open when Redis is unavailable | D-12 | Accepted |
| [0006](0006-rate-limit-only-the-public-api.md) | Rate limit only `/api/v1/*` | D-13 | Accepted |
| [0007](0007-429-problem-details.md) | Reject with 429 Problem Details `COMMON-429` and rate-limit headers | D-14 | Accepted |
| [0008](0008-separate-health-and-readiness.md) | Separate `/health` (liveness) from `/ready` (readiness) | D-16 | Accepted |
| [0009](0009-api-documentation-through-the-gateway.md) | Publish OpenAPI documentation, also through the gateway | D-18 | Accepted |
| [0010](0010-immediate-shutdown.md) | Stop immediately on Ctrl+C or SIGTERM, and clean up | D-20 | Accepted |

## Adding a record

Copy an existing record and give it the next number. Write it for someone
who was not in the discussion: what problem forced a choice, what was
decided, and what that costs. Raise a new decision for review before
implementing it (see [CONTRIBUTING](../../CONTRIBUTING.md)). To change an
accepted decision, add a new record that supersedes it and set the old
one's status to "Superseded by ADR-NNNN".
