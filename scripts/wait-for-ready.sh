#!/usr/bin/env bash
# Usage: scripts/wait-for-ready.sh [--timeout SECONDS] [URL ...]
#
# Polls each URL every 2 seconds until it answers HTTP 200, and fails if any
# URL is still not ready when the timeout (default 120 seconds) expires.
# With no URL, waits for the full stack's host-published readiness checks:
#   http://localhost/ready        gateway
#   http://localhost:8080/ready   Goal Service
#   http://localhost:8000/ready   Transaction Service
# Requires curl.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
handle_help "${1:-}"
timeout=120
if [ "${1:-}" = --timeout ]; then
  if [ $# -lt 2 ] || ! [[ $2 =~ ^[1-9][0-9]*$ ]]; then
    usage_error "--timeout needs a whole number of seconds"
  fi
  timeout=$2
  shift 2
fi
[ $# -gt 0 ] || set -- http://localhost/ready http://localhost:8080/ready http://localhost:8000/ready
command -v curl >/dev/null 2>&1 || die "curl is required"

deadline=$((SECONDS + timeout))
for url in "$@"; do
  # The status code is the last output line. No -o /dev/null: Git Bash's native
  # curl cannot open that path when path conversion is off (lib/common.sh).
  until
    output=$(curl -s --max-time 3 -w '\n%{http_code}' "$url")
    status=${output##*$'\n'}
    [ "$status" = 200 ]
  do
    [ "$SECONDS" -lt "$deadline" ] || die "$url not ready after ${timeout}s (last status: $status)"
    sleep 2
  done
  info "ready: $url"
done
