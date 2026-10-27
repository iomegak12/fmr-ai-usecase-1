# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Phase 1 Goal Service (Spring Boot 4.1.2 / Java 25) and Transaction Service
  (FastAPI 0.136.3 / Python 3.14) foundations with standalone runtime guides.
- Validated configuration, injectable clocks, RFC 9457 error handling,
  correlation IDs, local/JSON logging and safe startup summaries.
- Database-aware readiness, process liveness, Swagger/OpenAPI and Prometheus
  endpoints, with no CORS and immediate shutdown/resource cleanup.
- Maven Wrapper, Spotless, JaCoCo, uv dependency lockfile, Ruff and foundation
  unit tests enforcing at least 80% backend line coverage.
- Phase 0 repository layout with persistent service, gateway, scripts,
  architecture-decision and future test-suite placeholders.
- Repository ignore rules, editor settings and explicit script line endings.
- MIT license, Contributor Covenant 2.1, contribution guidelines, security
  policy and initial troubleshooting guide.
- Root and project README skeletons, full-stack environment example, and
  GitHub pull request and issue templates.

## [1.0.0] - Planned

This version has not been released. The following scope is planned, not shipped:

- Goal and Transaction backend services with PostgreSQL persistence.
- OpenResty gateway with Redis-backed rate limiting.
- API documentation, health/readiness checks and structured logging.
- Containers, cross-platform automation, unit-test quality gates and CI/CD.

Release notes and a release date will be finalized during P9.
