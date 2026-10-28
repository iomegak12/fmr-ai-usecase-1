#!/bin/bash
# Container health probe for the Goal Service image, which has no curl or wget.
# Sends an HTTP GET over bash's /dev/tcp and succeeds only on status 200.
#
# Usage: healthcheck [path]
#   healthcheck /health   liveness (the image HEALTHCHECK)
#   healthcheck /ready    readiness, including goal_db (Compose health checks)
set -eu

path=${1:-/health}
port=${GOAL_SERVICE_PORT:-8080}

exec 3<>"/dev/tcp/127.0.0.1/$port"
printf 'GET %s HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n' "$path" >&3
read -r -t 2 _ status _ <&3
[ "$status" = "200" ]
