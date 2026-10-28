# Security Policy

## Supported versions

| Version | Status |
|---|---|
| `main` (pre-release development) | Reports accepted; fixes target current development |
| `1.0.0` | Planned, not released or supported as a published release yet |
| Other versions | Unsupported |

There is no production-supported release yet. Update this table when
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
internet exposure. The services expose public Goal and Transaction APIs and internal
balance/deletion operations as well as health, documentation and metrics on
their direct ports. The gateway exposes the public APIs, documentation and
health only. None of these endpoints has authentication, and none may be
exposed to the public internet.

The Compose stack publishes the service and database ports (8080, 8000, 5432,
5433) on the host for local development only. Redis is not published. All
application containers run as a non-root user, and each receives only its
own database password. Base images are pinned, but they are not scanned or
signed in Release 1.

- The planned demo login is a frontend convenience, not a security boundary.
  The frontend and authentication/profile services are outside this backend
  implementation's scope.
- There is **no back-end authentication or authorization**. Anyone able to
  reach the APIs could read or modify demonstration data.
- Swagger/OpenAPI and direct service ports are intended for local development.
  Production documentation access policy and hosting are unresolved.
- The gateway answers `/internal/*` and metrics paths with 404, and its
  documentation routes forward only documentation paths. Direct service ports
  are not protected by that boundary; keep them off untrusted networks.
- CORS is intentionally disabled; this is not a replacement for authentication.
- Gateway rate limiting bypasses limiting and counting for 30 seconds after
  every start and fails open on Redis errors. It is a fairness control, not a
  security perimeter. Only list proxies you control in `TRUSTED_PROXIES`.
- Immediate shutdown and cross-service commits can leave database balances
  inconsistent; even a timed-out request may have committed remotely.
  Mismatch events support manual triage, not automatic reconciliation.

Use synthetic data only. Keep service and database access restricted to the
local development environment. Do not deploy publicly until authentication,
authorization, transport security, exposure policy and operational recovery
have been designed and reviewed.

## CI/CD and supply chain

- **Least privilege.** Workflows run with `contents: read` only. Checkouts do
  not keep the token (`persist-credentials: false`).
- **Pinned actions.** Third-party actions are pinned to full commit SHAs,
  with the version in a comment. Update them deliberately, reviewing each
  change.
- **Where secrets are used.** Registry credentials (`REGISTRY_USERNAME`,
  `REGISTRY_PASSWORD`) are used only to push from `main` or a release tag.
  Deployment secrets (`DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS`) are used only
  in `deploy.yml`, behind the `production` environment. Add required
  reviewers to that environment so every deployment is approved. Pull
  requests never receive them.
- **Deployment.** It verifies the host key against `DEPLOY_KNOWN_HOSTS` and
  validates every value used in its remote command. The SSH key is removed
  when the job ends.
- **Images.** Images are built from pinned base images and checked to run as
  uid 10001. They are not scanned or signed in Release 1.

## Secrets and local configuration

Copy [.env.example](.env.example) to `.env` locally and supply unique development
passwords. The example deliberately contains blank password values. Never
commit `.env`, credentials or `*.dump` files; never put secrets in logs or
startup banners.

Ignore rules do not protect files already tracked by Git. If a credential is
exposed, revoke or rotate it immediately and contact the maintainer to
coordinate cleanup. Removing it from the latest file alone is not sufficient.
