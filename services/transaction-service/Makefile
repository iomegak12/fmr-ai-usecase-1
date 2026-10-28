# Transaction Service Makefile (plan Section 5.8, D-25). Run from this directory.
#
# Code-quality targets run the repository scripts for this project only,
# through uv and the locked dependency set. The Compose targets use this
# directory's docker-compose.yml (transaction-service and transaction-db).

include ../../scripts/lib/scripts.mk

.DEFAULT_GOAL := help
.PHONY: help format lint test coverage migrate run clean build up down ps logs

help:
	$(info $()Transaction Service targets:)
	$(info $()  make format     Ruff import sorting and format)
	$(info $()  make lint       Ruff check and format check)
	$(info $()  make test       Unit tests)
	$(info $()  make coverage   Unit tests with the pytest-cov 80 percent gate)
	$(info $()  make migrate    alembic upgrade head against the database in .env)
	$(info $()  make run        Run on the host with the local profile (run make migrate first))
	$(info $()  make clean      Remove caches and coverage output)
	$(info $()  make build      Build the image)
	$(info $()  make up         Start transaction-service and transaction-db and wait until healthy)
	$(info $()  make down       Stop them; the data volume is kept)
	$(info $()  make ps         Show container status)
	$(info $()  make logs       Follow the logs)
	@cd .

format:
	$(call script,format) txn

lint:
	$(call script,lint) txn

test:
	$(call script,test) txn

coverage:
	$(call script,coverage) txn

migrate:
	$(call script,migrate)

run:
	$(call script,run) txn

clean:
	$(call script,clean) txn

build:
	$(COMPOSE) build

up:
	$(COMPOSE) up -d --build --wait --wait-timeout 300

down:
	$(COMPOSE) down

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f --tail=200
