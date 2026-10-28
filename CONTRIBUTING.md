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

All plan phases (P0 to P9) are implemented; the plan's execution evidence
records what each one delivered and how it was verified. The
[architecture decision records](docs/adr/README.md) explain the major
deviations from the LLD, and the [LLD 1.1 update list](docs/Kalash_LLD_v1.1_Updates.md)
tracks the LLD changes they require. Run `make help` at the root or in a
project directory for the available commands.

When changing a Dockerfile or compose file, keep images non-root, pin base
images to exact versions, pass a container only the variables it needs, and
confirm that `make up` still reaches all-healthy. Never bake `.env` or
credentials into an image; each `.dockerignore` excludes them.

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

The CI workflows check these rules on every pull request once branch
protection requires them (see [Tests and quality gates](#tests-and-quality-gates)).

## Releases

Releases use Semantic Versioning and a `vX.Y.Z` tag. The three projects are
released together with the same version.

1. On a release branch, set the version everywhere it appears:
   - `services/goal-service/pom.xml` `<version>`, and `ARG VERSION` in its
     `Dockerfile`;
   - `services/transaction-service/pyproject.toml` `version` (then run
     `uv lock`), and `ARG VERSION` in its `Dockerfile`;
   - `ARG GATEWAY_VERSION` in `gateway/Dockerfile`;
   - the `VERSION`/`GATEWAY_VERSION` build arguments and image tags in the
     root and the three project `docker-compose.yml` files, including the
     `KALASH_IMAGE_TAG` default.
2. In [CHANGELOG](CHANGELOG.md), replace "Unreleased" in the version's
   heading with the date, and start a new empty `[Unreleased]` section. In
   [SECURITY](SECURITY.md), update the supported-versions table.
3. Run `make lint` and `make coverage`, open a pull request and merge it.
4. Tag the merge commit: `git tag -a vX.Y.Z -m "Kalash X.Y.Z"` and
   `git push origin vX.Y.Z`. The three pipelines build every project, check
   that the tag equals each project's version, and push images tagged
   `X.Y.Z` and the git SHA.
5. Publish a GitHub release for the tag. `deploy.yml` waits for the images,
   then deploys them once the host is configured.

## Repository and dependency rules

- Keep application source under its project, never at the repository root.
- Use feature-based packages. Controllers and routers delegate business logic
  to services; features may use `common` but not other features' repositories.
- The Transaction Service may call the Goal Service, never the reverse.
- Each project builds, tests and runs independently, with its own README,
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
Make recipes use tabs. Automation scripts have matching Bash (`.sh`) and
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

- Add or update unit tests in the same pull request as the behaviour change.
- Goal Service: JUnit Jupiter API, Mockito, AssertJ and controller slices;
  JaCoCo enforces at least **80% line coverage**. Spring Boot 4.1.2 manages
  Jupiter 6.0.3, verified in P1.
- Transaction Service: pytest, FastAPI TestClient and respx;
  pytest-cov must enforce at least **80% line coverage**.
- Gateway: busted and test doubles for Redis, the clock and `ngx`;
  report coverage with luacov, with no numeric gate. Run luacheck and the
  specs in the gateway's `test` image (see the gateway README). When the route
  table changes, keep `spec/routes_spec.lua` in step, so that only `/api/v1/*`
  is ever rate limited.
- Unit tests must not start databases or Redis or make real network requests.
  Inject fixed clocks; tests must not depend on the current date or time.
- Cover successful paths, validation, boundary values and failure paths.
  Every LLD Section 21.2 error code plus `COMMON-429` needs a test.
- Run Spotless checks, Ruff checks and format checks, and luacheck for changed
  projects, then their unit tests and coverage checks, and include the results
  in the PR.
- Integration and end-to-end suites are deferred; their README placeholders
  must not be presented as passing tests.

Before a pull request, run `make format`, `make lint` and `make coverage`
from the root, or the same targets from each changed project's directory.
`make test` runs the unit tests without the coverage gates.

The pipelines in `.github/workflows` run the same targets on every pull
request. A project the PR does not change reports its jobs as skipped, which
counts as passing. To enforce "every changed project's pipeline passes before
merge", protect `main` with these required status checks:

- `goal-service verify` and `goal-service image / build and push`
- `transaction-service verify` and `transaction-service image / build and push`
- `gateway verify` and `gateway image / build and push`

Branch protection and the CI variables and secrets are repository settings;
the workflows cannot apply them. See [CI/CD](README.md#14-cicd) for those
settings.

When adding automation, add both a `.sh` and a `.ps1` script to
[scripts](scripts/README.md) with the same arguments and behaviour. Start
each with its usage comment, fail fast, keep the PowerShell version
compatible with Windows PowerShell 5.1, and call it from the Makefiles
through `$(call script,NAME)`. Never print secrets or pass them on a command
line.

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
