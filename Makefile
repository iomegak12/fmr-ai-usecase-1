# Kalash root Makefile (plan Section 5.8, D-25).
#
# Code-quality and service targets call the per-project Makefiles; those, and
# the root targets here, run the matching scripts/NAME.ps1 on Windows or
# scripts/NAME.sh elsewhere (see scripts/lib/scripts.mk). The full-stack
# Compose lifecycle calls Docker Compose directly. Requires GNU Make; the
# recipes run the same from PowerShell, cmd or Bash.

include scripts/lib/scripts.mk

GOAL := services/goal-service
TXN := services/transaction-service
GATEWAY := gateway

.DEFAULT_GOAL := help
.PHONY: help setup format lint test test-goal test-txn test-gateway coverage \
	build up down restart ps logs run-goal run-txn migrate backup restore clean

help:
	$(info $()Kalash targets:)
	$(info $()  make setup         Check tools, create missing .env files, install Transaction dependencies)
	$(info $()  make format        Format Java (Spotless) and Python (Ruff))
	$(info $()  make lint          Spotless check, Ruff check and format check, luacheck)
	$(info $()  make test          Unit tests for all three projects)
	$(info $()  make test-goal     Goal Service unit tests only (also test-txn, test-gateway))
	$(info $()  make coverage      Unit tests with coverage reports and the 80 percent gates)
	$(info $()  make build         Build the gateway, Goal and Transaction images)
	$(info $()  make up            Build if needed, start the full stack and wait until it is ready)
	$(info $()  make down          Stop and remove the stack containers and network; data volumes are kept)
	$(info $()  make restart       down, then up)
	$(info $()  make ps            Show container status and health)
	$(info $()  make logs          Follow the logs of every container)
	$(info $()  make run-goal      Run the Goal Service on the host (local profile, coloured logs))
	$(info $()  make run-txn       Run the Transaction Service on the host (run make migrate first))
	$(info $()  make migrate       Apply the Transaction Service migrations (Flyway runs at Goal start-up))
	$(info $()  make backup        Back up both stack databases to BACKUP_DIR (or DB=goal_db))
	$(info $()  make restore DB=goal_db FILE=backups/goal_db/YYYY-MM-DD.dump   Replace a database from a backup)
	$(info $()  make clean         Remove build output, caches and coverage reports)
	$(info $()Start with make setup. Each project directory also has its own Makefile.)
	@cd .

setup:
	$(call script,setup)

format:
	$(MAKE) -C $(GOAL) format
	$(MAKE) -C $(TXN) format

lint test coverage clean:
	$(MAKE) -C $(GOAL) $@
	$(MAKE) -C $(TXN) $@
	$(MAKE) -C $(GATEWAY) $@

test-goal:
	$(MAKE) -C $(GOAL) test

test-txn:
	$(MAKE) -C $(TXN) test

test-gateway:
	$(MAKE) -C $(GATEWAY) test

build:
	$(COMPOSE) build

up:
	$(COMPOSE) up -d --build --wait --wait-timeout 300
	$(call script,wait-for-ready)

down:
	$(COMPOSE) down

restart: down up

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f --tail=200

run-goal:
	$(MAKE) -C $(GOAL) run

run-txn:
	$(MAKE) -C $(TXN) run

migrate:
	$(MAKE) -C $(TXN) migrate

backup:
	$(call script,backup) $(DB)

restore:
	$(if $(and $(DB),$(FILE)),,$(error Usage: make restore DB=goal_db|transaction_db FILE=path/to/file.dump))
	$(call script,restore) $(DB) "$(FILE)"
