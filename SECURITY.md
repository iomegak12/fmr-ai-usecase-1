# Security Policy

## Supported versions

| Version | Status |
|---|---|
| `main` (pre-release development) | Reports accepted; fixes target current development |
| `1.0.0` | Planned, not released or supported as a published release yet |
| Other versions | Unsupported |

There is no production-supported release at Phase 1. Update this table when
version 1.0.0 is actually released.

## Reporting a vulnerability

Email [jd.ramkumar@gmail.com](mailto:jd.ramkumar@gmail.com) privately with the
subject `Kalash security report`.

Include the affected commit or version, component, reproduction steps,
expected and observed behavior, potential impact and redacted supporting
logs. Do not include passwords, database dumps, financial records or other
sensitive personal data. Do not open a public issue or publish exploit details
before coordinating disclosure with the maintainer.

The maintainer will review the report, request further details if needed and
coordinate remediation and disclosure by email. No response-time or fix-time
SLA is currently offered.

## Release 1 limitations

Release 1 is designed for a **local demonstration**, not production or public
internet exposure. Phase 1 services expose health, documentation and metrics;
business APIs are not implemented yet.

- The planned demo login is a frontend convenience, not a security boundary.
  The frontend and authentication/profile services are outside this backend
  implementation's scope.
- There is **no back-end authentication or authorization**. Anyone able to
  reach the APIs could read or modify demonstration data.
- Swagger/OpenAPI and direct service ports are intended for local development.
  Production documentation access policy and hosting are unresolved.
- Internal routes are planned to be blocked by the gateway, but direct
  service access is not protected by that boundary.
- CORS is intentionally disabled; this is not a replacement for authentication.
- Planned gateway rate limiting bypasses limiting and counting for 30 seconds
  after startup and fails open on Redis errors. It is not a security perimeter.
- Immediate shutdown and cross-service commits can leave database balances
  inconsistent; automatic reconciliation is not part of Release 1.

Use synthetic data only. Keep service and database access restricted to the
local development environment. Do not deploy publicly until authentication,
authorization, transport security, exposure policy and operational recovery
have been designed and reviewed.

## Secrets and local configuration

Copy [.env.example](.env.example) to `.env` locally and supply unique development
passwords. The example deliberately contains blank password values. Never
commit `.env`, credentials or `*.dump` files; never put secrets in logs or
startup banners.

Ignore rules do not protect files already tracked by Git. If a credential is
exposed, revoke or rotate it immediately and contact the maintainer to
coordinate cleanup. Removing it from the latest file alone is not sufficient.
