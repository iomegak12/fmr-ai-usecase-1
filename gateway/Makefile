# API Gateway Makefile (plan Section 5.8, D-25). Run from this directory.
#
# Code-quality targets run luacheck, busted and luacov in the gateway's test
# image. There is no Lua formatter; luacheck enforces style. The Compose
# targets use this directory's docker-compose.yml (gateway and redis).

include ../scripts/lib/scripts.mk

.DEFAULT_GOAL := help
.PHONY: help lint test coverage clean build up down ps logs

help:
	$(info $()API Gateway targets:)
	$(info $()  make lint       luacheck)
	$(info $()  make test       busted unit tests)
	$(info $()  make coverage   busted with the luacov report (no gate))
	$(info $()  make clean      Remove luacov output)
	$(info $()  make build      Build the image)
	$(info $()  make up         Start the gateway and Redis and wait until healthy)
	$(info $()  make down       Stop them)
	$(info $()  make ps         Show container status)
	$(info $()  make logs       Follow the logs)
	@cd .

lint:
	$(call script,lint) gateway

test:
	$(call script,test) gateway

coverage:
	$(call script,coverage) gateway

clean:
	$(call script,clean) gateway

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
