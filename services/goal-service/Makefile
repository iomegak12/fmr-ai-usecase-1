# Goal Service Makefile (plan Section 5.8, D-25). Run from this directory.
#
# Code-quality targets run the repository scripts for this project only. The
# Maven steps use Java 25 on the host, or the Maven image when the host has
# no Java 25 (override with GOAL_RUNNER=host or docker). The Compose targets
# use this directory's docker-compose.yml (goal-service and goal-db).

include ../../scripts/lib/scripts.mk

.DEFAULT_GOAL := help
.PHONY: help format lint test coverage run clean build up down ps logs

help:
	$(info $()Goal Service targets:)
	$(info $()  make format     Spotless apply)
	$(info $()  make lint       Spotless check)
	$(info $()  make test       Unit tests)
	$(info $()  make coverage   Unit tests with the JaCoCo 80 percent gate)
	$(info $()  make run        Run on the host with the local profile (reads .env))
	$(info $()  make clean      Remove target/)
	$(info $()  make build      Build the image)
	$(info $()  make up         Start goal-service and goal-db and wait until healthy)
	$(info $()  make down       Stop them; the data volume is kept)
	$(info $()  make ps         Show container status)
	$(info $()  make logs       Follow the logs)
	@cd .

format:
	$(call script,format) goal

lint:
	$(call script,lint) goal

test:
	$(call script,test) goal

coverage:
	$(call script,coverage) goal

run:
	$(call script,run) goal

clean:
	$(call script,clean) goal

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
