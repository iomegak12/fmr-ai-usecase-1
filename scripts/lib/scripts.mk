# Shared Make definitions for the root and per-project Makefiles (D-25).
#
# $(call script,NAME) expands to the command that runs scripts/NAME.ps1 on
# Windows, or scripts/NAME.sh elsewhere. Override with SCRIPT_SHELL=sh (for
# example in Git Bash) or SCRIPT_SHELL=ps1, and choose the PowerShell
# executable with POWERSHELL=powershell (Windows PowerShell 5.1).

KALASH_SCRIPTS := $(patsubst %/lib/,%,$(dir $(lastword $(MAKEFILE_LIST))))

ifeq ($(OS),Windows_NT)
SCRIPT_SHELL ?= ps1
else
SCRIPT_SHELL ?= sh
endif
POWERSHELL ?= pwsh

ifeq ($(SCRIPT_SHELL),ps1)
script = $(POWERSHELL) -NoLogo -NoProfile -ExecutionPolicy Bypass -File $(KALASH_SCRIPTS)/$(1).ps1
else ifeq ($(SCRIPT_SHELL),sh)
script = bash $(KALASH_SCRIPTS)/$(1).sh
else
$(error SCRIPT_SHELL must be ps1 or sh)
endif

COMPOSE ?= docker compose

# Image labels (plan Section 5.6): git commit and its commit time. Using the
# commit time rather than the wall clock keeps builds reproducible, so
# `make up` on unchanged sources reuses the images and leaves running
# containers alone.
GIT_SHA ?= $(or $(shell git rev-parse --short HEAD),unknown)
BUILD_DATE ?= $(or $(shell git log -1 --format=%cI),unknown)
export GIT_SHA BUILD_DATE
