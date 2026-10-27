# Contributing to Kalash

Follow the [Code of Conduct](CODE_OF_CONDUCT.md). Send vulnerability reports
privately using the [security policy](SECURITY.md), not public issues.

## Scope and design references

Release 1 covers the Goal Service, Transaction Service and API Gateway. The
frontend, authentication service, integration tests and end-to-end tests are
outside this implementation's scope.

Read the [implementation plan](docs/Kalash_Project_Impl_Plan_Opus_v1.0.md),
[BRD](docs/Kalash_BRD_v1.0.md), [HLD](docs/Kalash_HLD_v1.1.md) and
[LLD](docs/Kalash_LLD_v1.0.md) before changing behavior. The implementation
plan's decision register records deliberate deviations from the LLD. Raise
conflicting or new decisions for review instead of silently changing the design.

Phase 0 provides repository scaffolding and governance. Phase 1 adds both
service build manifests, foundation code, formatters and unit tests. Business
features, Make targets, containers and CI remain in their respective phases.
Use the service READMEs for the available build and validation commands.

## Branches and commits

- Branch from an up-to-date `main`; use short-lived `feat/<topic>`,
  `fix/<topic>`, `docs/<topic>` or `chore/<topic>` branches.
- Submit changes through a pull request to `main`; keep each PR focused on one
  concern and link its issue, phase and relevant business rules.
- Use Conventional Commits: `type(scope): description`, for example
  `feat(goals): validate target dates`. Types include `feat`, `fix`, `docs`,
  `test`, `refactor`, `build`, `ci` and `chore`. Mark breaking changes with `!`
  and explain them in a `BREAKING CHANGE:` footer.
- Do not commit credentials, `.env` files, database dumps, caches or generated
  build output. Commit dependency lockfiles and the Maven Wrapper when added.
- Describe user-visible changes under `Unreleased` in the
  [changelog](CHANGELOG.md). Use Semantic Versioning for releases.

These are contributor requirements, not a claim that remote branch protection
or CI enforcement has already been configured.

## Repository and dependency rules

- Keep application source under its project, never at the repository root.
- Use feature-based packages. Controllers and routers delegate business logic
  to services; features may use `common` but not other features' repositories.
- The Transaction Service may call the Goal Service, never the reverse.
- Each project will build, test and run independently, with its own README,
  Makefile, Compose file and environment example.
- Mirror production package structure in unit tests. Remove a directory's
  `.gitkeep` when adding real files to it.

## Coding standards

| Area | Requirement |
|---|---|
| Java | Standard Java conventions; Spotless formatting |
| Python | PEP 8, type hints; Ruff linting and formatting; dependencies managed with `uv` |
| Lua | LuaDoc for public interfaces; luacheck linting |
| Database names | `snake_case`, plural table names |
| JSON fields | `camelCase` |
| Enums | `UPPER_CASE`, such as `ACTIVE` and `DEPOSIT` |
| URL paths | Lowercase plural nouns; kebab-case for multi-word segments |
| Money | Whole rupees using Java `long` or Python `int`; no floating point |
| Business dates | Java `LocalDate` or Python `date` |
| Timestamps | Java `OffsetDateTime` or timezone-aware Python `datetime`, in UTC |
| Today's date | Injected clock using `APP_TIMEZONE` (default `Asia/Kolkata`), never the system default |

Follow the repository's EditorConfig and Git attributes. Shell scripts use LF;
Make recipes use tabs. Automation scripts will have matching Bash (`.sh`) and
PowerShell (`.ps1`) versions, a usage comment and fail-fast error handling.

### Database access

Use Spring Data JPA repositories, derived queries or JPQL in Java and SQLAlchemy
2.x ORM in Python (`select()`, `session.add()`, `session.delete()`).
Do not use native SQL queries, `JdbcTemplate`, string-built SQL, `text()`,
`exec_driver_sql` or raw cursors in application code. Flyway migration scripts
may contain SQL; Alembic migrations must use the `op` API.

### Documentation comments

Document major business code according to implementation plan Section 7.8:

| Language | Required documentation |
|---|---|
| Java | Javadoc on public classes and methods in `goal`, `balance`, `insights` and `common.error`, including applicable `@param`, `@return` and `@throws` tags |
| Python | Google-style docstrings on public modules, classes and functions in `transactions`, `goal_deletion`, `clients` and `common` |
| Lua | LuaDoc on every module and public function in `lua/kalash` |

State the business rules implemented, for example `Implements BR-12, BR-14`,
where applicable; do not invent rule IDs for infrastructure helpers. Explain
non-obvious behavior rather than narrating code. Reviewers enforce these
documentation requirements; they are not a build gate.

## Tests and quality gates

- Add or update unit tests alongside behavior changes (P2-P4), not afterward.
- Goal Service: JUnit Jupiter API, Mockito, AssertJ and controller slices;
  JaCoCo enforces at least **80% line coverage**. Spring Boot 4.1.2 manages
  Jupiter 6.0.3, verified in P1.
- Transaction Service: pytest, FastAPI TestClient and respx;
  pytest-cov must enforce at least **80% line coverage**.
- Gateway: busted and test doubles for Redis, the clock and `ngx`;
  report coverage with luacov, with no numeric gate.
- Unit tests must not start databases or Redis or make real network requests.
  Inject fixed clocks; tests must not depend on the current date or time.
- Cover successful paths, validation, boundary values and failure paths.
  Every LLD Section 21.2 error code plus `COMMON-429` needs a test.
- Run Spotless checks, Ruff checks and format checks, and luacheck for changed
  projects once those tools are configured. Run their unit tests and coverage
  checks and include results in the PR.
- Integration and end-to-end suites are deferred; their README placeholders
  must not be presented as passing tests.

The planned root commands include `make lint`, `make test` and `make coverage`.
They are **not available in Phase 1**; use service-local commands instead.
Once P8 pipelines exist, every affected
project's pipeline must pass before merge.

## Pull request checklist

- [ ] Scope, phase, linked issue and applicable business rules are identified.
- [ ] Dependency, naming, money/date and ORM-only rules are followed.
- [ ] Business-code documentation comments are present and accurate.
- [ ] Relevant unit tests and boundary/error cases are covered.
- [ ] Available lint, format, test and coverage checks pass; unavailable checks
      are explicitly marked as such with a reason.
- [ ] README, configuration examples and changelog are updated where needed.
- [ ] No credentials, personal data, dumps or generated output are included.
- [ ] Any deviation from the agreed design is documented for approval.
