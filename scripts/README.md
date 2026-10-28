# Automation scripts

Every task has a Bash script (`NAME.sh`) and a PowerShell script
(`NAME.ps1`) with the same arguments and behaviour (D-25). The root
[Makefile](../Makefile) and the per-project Makefiles call them: the `.ps1`
version on Windows and the `.sh` version elsewhere. Each script starts with
its usage text, which `--help` (Bash) or `-Help` (PowerShell) prints. Each one
stops at the first failure with a non-zero exit code: 2 for a usage error,
otherwise the failing tool's code or 1.

| Script | Make target(s) | What it does |
|---|---|---|
| `setup` | `setup` | Checks the tools, creates missing `.env` files, runs `uv sync --locked` |
| `format` | `format` | Spotless apply; Ruff import sorting and format |
| `lint` | `lint` | Spotless check; Ruff check and format check; luacheck |
| `test` | `test`, `test-goal`, `test-txn`, `test-gateway` | Unit tests, without coverage gates |
| `coverage` | `coverage` | Unit tests with coverage reports; 80% gates for both services |
| `run` | `run-goal`, `run-txn` | Runs one service on the host with the `local` profile |
| `migrate` | `migrate` | `alembic upgrade head` for the Transaction Service |
| `backup` | `backup` | `pg_dump` of the stack databases, with retention |
| `restore` | `restore DB=... FILE=...` | Replaces a stack database from a backup |
| `clean` | `clean` | Removes build output, caches and coverage reports |
| `wait-for-ready` | `up` | Waits until the stack's readiness URLs answer 200 |

`lint`, `test`, `coverage` and `clean` take project names: `goal`, `txn`,
`gateway` or `all` (the default). `format` takes `goal` and `txn`; the
gateway has no Lua formatter. `backup` takes `goal_db`, `transaction_db` or
`all` (the default).

## Tools each project needs

| Project | Runs with | Notes |
|---|---|---|
| Goal Service | Maven Wrapper and Java 25 | Uses the host JDK when it is Java 25 or newer. Otherwise runs in `maven:3.9.11-eclipse-temurin-25` with the `kalash-goal-maven-cache` volume. Set `GOAL_RUNNER=host` or `docker` to choose. |
| Transaction Service | uv | Always runs on the host with the locked dependency set. |
| Gateway | Docker | Builds the Dockerfile's `test` stage (`kalash/gateway-test`) and runs luacheck, busted and luacov in it, with no network. |

## Choosing the script flavour

Make picks `.ps1` when `OS=Windows_NT` and `.sh` otherwise. Override it with
`SCRIPT_SHELL=sh` (for example from Git Bash) or `SCRIPT_SHELL=ps1`. Make
calls PowerShell 7 (`pwsh`); use `POWERSHELL=powershell` for Windows
PowerShell 5.1, which the scripts also support. Without Make, run a script
directly from any directory, for example `bash scripts/test.sh txn` or
`pwsh scripts/test.ps1 txn`.

## Environment files

`setup` copies each missing `.env` from its `.env.example`: the root, both
services and the gateway. A blank `GOAL_DB_PASSWORD` or `TXN_DB_PASSWORD` gets
a random 32-character development password. The same password goes into every
file that defines that variable, so host runs, the root stack and the project
stacks can share a database. A password already set in an existing `.env` is
reused. Existing `.env` files are never changed, and passwords are never
printed.

`run goal` loads `services/goal-service/.env` into the process environment,
because Spring does not read `.env`; variables already set in the environment
win. Values are never put on a command line. Without Java 25, the service
runs in the Maven image with `GOAL_SERVICE_PORT` published, and a `localhost`
database host becomes `host.docker.internal`.

## Backups

`backup` and `restore` act on the root Compose stack (`make up`) and follow
LLD Section 29:

- `backup` runs `pg_dump -Fc` inside the database container and checks the
  dump with `pg_restore --list`. It then copies the dump to
  `BACKUP_DIR/<db>/<YYYY-MM-DD>.dump`; another backup on the same day
  replaces that file. Dated dumps older than `BACKUP_RETENTION_DAYS` are then
  deleted. Both settings come from the environment or the root `.env`, with
  defaults of `./backups` (ignored by Git) and `7`.
- `restore DB=goal_db FILE=...` first checks that the file is a backup of
  that same database, so a `transaction_db` dump cannot be loaded into
  `goal_db`. It then stops the database's own service, runs
  `pg_restore --clean --if-exists --single-transaction`, and starts the
  service again, even after a failure. A failed restore leaves the database
  unchanged. Restoring one database does not roll back the other, so restore
  both from the same day.
- Scheduling is not automated (D-30). For the LLD's daily 02:00 IST backup,
  add a host cron entry such as
  `0 2 * * * cd /path/to/kalash && bash scripts/backup.sh`, or a Windows Task
  Scheduler task that runs `pwsh -File C:\path\to\kalash\scripts\backup.ps1`.

Dumps contain financial demonstration data. Keep `BACKUP_DIR` private and out
of version control.

## Layout

```
scripts/
|-- NAME.sh / NAME.ps1   one pair per task
`-- lib/
    |-- common.sh        shared Bash helpers (sourced)
    |-- common.ps1       shared PowerShell helpers (dot-sourced)
    `-- scripts.mk       Make include: script flavour, COMPOSE, image labels
```
