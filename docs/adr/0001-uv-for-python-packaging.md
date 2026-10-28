# ADR-0001: Use uv with a lockfile for Python packaging

- **Status:** Accepted
- **Date:** 2026-10-28
- **Decision register:** D-04
- **LLD impact:** Deviation from LLD §27, §28 and Open Issue 6 (`pip` with
  `requirements.txt`)

## Context

The LLD proposed `pip install -r requirements.txt` for the Transaction
Service. A requirements file pins only what is listed in it. It does not
record transitive versions or hashes unless a separate tool generates it,
and it says nothing about the Python version. Release 1 also needs the same
dependency set on developer machines, in CI and in the image.

## Decision

The Transaction Service is managed with [uv](https://docs.astral.sh/uv/):

- `pyproject.toml` declares runtime and development dependencies,
  `requires-python = ">=3.14,<3.15"`, and the Ruff, pytest and coverage
  settings.
- `uv.lock` is committed and pins the full dependency graph with hashes.
- `.python-version` selects Python 3.14; uv installs it when it is missing.
- Every command runs with `--locked` (`uv run --locked ...`,
  `uv sync --locked`), so a stale lockfile fails instead of re-resolving.
- The image uses `uv sync --frozen --no-dev` from the pinned
  `ghcr.io/astral-sh/uv:0.9.16` image into a virtual environment, and the
  runtime stage contains no uv.

## Consequences

- Developers, CI (`astral-sh/setup-uv` pinned to uv 0.9.16) and the image
  resolve the identical set of packages.
- Contributors need uv; `make setup` checks for it and runs
  `uv sync --locked`.
- Adding or upgrading a dependency is `uv add` or `uv lock --upgrade-package`,
  and the lockfile change is reviewed with the code.
- There is no `requirements.txt`. Tools that need one can export it with
  `uv export --locked`.

## References

- `services/transaction-service/pyproject.toml`, `uv.lock`, `Dockerfile`
- Plan Section 5.2 (P1 tasks) and Section 5.6 (P5 image)
