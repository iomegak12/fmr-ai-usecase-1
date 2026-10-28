#!/bin/sh
# Kalash API Gateway container entrypoint (plan Section 5.5).
#
# 1. Validates the environment-driven settings nginx cannot read itself and
#    renders them into conf/generated/: upstream addresses, the DNS resolver
#    and the trusted-proxy list for real_ip.
# 2. When starting OpenResty, checks the full configuration first (this also
#    runs the Lua settings validation), then prints the start-up banner.
# 3. Replaces itself with the command (exec), so OpenResty receives the
#    container's stop signal (SIGQUIT) directly.
#
# Usage: docker-entrypoint.sh [command...]   (default: openresty in foreground)
set -eu

CONF_DIR=${KALASH_CONF_DIR:-/usr/local/openresty/nginx/conf}
GENERATED_DIR="$CONF_DIR/generated"

GOAL_SERVICE_UPSTREAM=${GOAL_SERVICE_UPSTREAM:-goal-service:8080}
TXN_SERVICE_UPSTREAM=${TXN_SERVICE_UPSTREAM:-transaction-service:8000}
TRUSTED_PROXIES=${TRUSTED_PROXIES:-}
GATEWAY_RESOLVER=${GATEWAY_RESOLVER:-}

fail() {
  printf 'kalash-gateway: %s\n' "$*" >&2
  exit 64
}

# host:port with a DNS name or IPv4 address; nothing that could break out of
# the nginx directive it is written into.
check_upstream() {
  name=$1
  value=$2
  case "$value" in
    '' | *[!A-Za-z0-9.:-]*) fail "$name must be host:port (got '$value')" ;;
  esac
  host=${value%:*}
  port=${value##*:}
  case "$host" in
    '' | *:*) fail "$name must be host:port (got '$value')" ;;
  esac
  case "$port" in
    '' | *[!0-9]*) fail "$name must be host:port (got '$value')" ;;
  esac
  if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    fail "$name port must be between 1 and 65535 (got '$value')"
  fi
}

render_upstreams() {
  check_upstream GOAL_SERVICE_UPSTREAM "$GOAL_SERVICE_UPSTREAM"
  check_upstream TXN_SERVICE_UPSTREAM "$TXN_SERVICE_UPSTREAM"
  sed -e "s|@GOAL_SERVICE_UPSTREAM@|$GOAL_SERVICE_UPSTREAM|g" \
    -e "s|@TXN_SERVICE_UPSTREAM@|$TXN_SERVICE_UPSTREAM|g" \
    "$CONF_DIR/conf.d/upstreams.conf.template" >"$GENERATED_DIR/upstreams.conf"
}

# Docker's embedded DNS (127.0.0.11) is the first nameserver on a Compose
# network; GATEWAY_RESOLVER overrides it.
render_resolver() {
  resolver=$GATEWAY_RESOLVER
  if [ -z "$resolver" ]; then
    resolver=$(awk '$1 == "nameserver" { print $2; exit }' /etc/resolv.conf 2>/dev/null || true)
  fi
  resolver=${resolver:-127.0.0.11}
  case "$resolver" in
    *[!0-9A-Fa-f.:]*) fail "GATEWAY_RESOLVER must be an IP address (got '$resolver')" ;;
    *:*) resolver="[$resolver]" ;;
  esac
  printf 'resolver %s valid=10s ipv6=off;\nresolver_timeout 2s;\n' "$resolver" \
    >"$GENERATED_DIR/resolver.conf"
  RESOLVER=$resolver
}

# TRUSTED_PROXIES: comma- or space-separated IP addresses or CIDR ranges.
render_trusted_proxies() {
  out="$GENERATED_DIR/trusted_proxies.conf"
  printf '# Rendered from TRUSTED_PROXIES; empty means no proxy is trusted.\n' >"$out"
  TRUSTED_LIST=
  for proxy in $(printf '%s' "$TRUSTED_PROXIES" | tr ',' ' '); do
    case "$proxy" in
      *[!0-9A-Fa-f.:/]*) fail "TRUSTED_PROXIES entry '$proxy' is not an IP address or CIDR range" ;;
    esac
    printf 'set_real_ip_from %s;\n' "$proxy" >>"$out"
    TRUSTED_LIST="${TRUSTED_LIST:+$TRUSTED_LIST, }$proxy"
  done
}

# Validate the limiter settings with the same Lua module nginx loads in
# init_by_lua (openresty -t does not run init_by_lua), and read back the
# effective values for the banner.
load_limiter_settings() {
  settings=$(/usr/local/openresty/luajit/bin/luajit -e '
    package.path = "/usr/local/openresty/nginx/lua/?.lua;" .. package.path
    local ok, c = pcall(require("kalash.config").load)
    if not ok then
      io.stderr:write("kalash-gateway: ", tostring(c), "\n")
      os.exit(64)
    end
    io.write(c.requests, " ", c.window_seconds, " ", c.warmup_seconds, " ",
      c.redis.host, " ", c.redis.port, " ", c.redis.timeout_ms)') || exit 64
  # shellcheck disable=SC2086 # word splitting is intended
  set -- $settings
  limit=$1 window=$2 warmup=$3 redis_host=$4 redis_port=$5 redis_timeout=$6
}

print_banner() {
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    bold=$(printf '\033[1m') cyan=$(printf '\033[36m') green=$(printf '\033[32m')
    yellow=$(printf '\033[33m') reset=$(printf '\033[0m')
  else
    bold='' cyan='' green='' yellow='' reset=''
  fi

  warmup_end=$(date -u -d "@$(($(date -u +%s) + warmup))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "start + ${warmup}s")
  openresty_version=$(openresty -v 2>&1 | sed 's/^nginx version: //')

  row() {
    printf '  %s%-12s%s %s\n' "$cyan" "$1" "$reset" "$2"
  }

  printf '\n%s%s  Kalash API Gateway %s%s\n' "$bold" "$green" "${KALASH_GATEWAY_VERSION:-dev}" "$reset"
  row "Runtime" "$openresty_version, pid $$"
  row "Listening" "port 80 (container); landing page /"
  row "API" "/api/v1/goals -> $GOAL_SERVICE_UPSTREAM"
  row "" "/api/v1/transactions -> $TXN_SERVICE_UPSTREAM"
  row "Docs" "/docs/goals/  /docs/transactions/"
  row "Health" "/health  /ready  /health/{goals,transactions}  /ready/{goals,transactions}"
  row "Rate limit" "$limit requests per ${window}s per client IP on /api/v1/*"
  row "Warm-up" "${warmup}s, limiter off until ${yellow}${warmup_end}${reset}"
  row "Redis" "$redis_host:$redis_port, timeout $redis_timeout ms, fail open"
  row "Proxies" "trusted: ${TRUSTED_LIST:-none}; resolver $RESOLVER"
  row "Blocked" "/internal/*, metrics endpoints"
  row "Log level" "notice (JSON access log to stdout)"
  printf '\n'
}

mkdir -p "$GENERATED_DIR"
render_upstreams
render_resolver
render_trusted_proxies

if [ "$#" -eq 0 ]; then
  set -- /usr/local/openresty/bin/openresty -g 'daemon off;'
fi

case "$1" in
  openresty | */openresty | nginx | */nginx)
    is_test=false
    for arg in "$@"; do
      case "$arg" in -t | -T) is_test=true ;; esac
    done
    if [ "$is_test" = false ]; then
      load_limiter_settings
      /usr/local/openresty/bin/openresty -t -q || fail "configuration check failed; see the error above"
      print_banner
    fi
    ;;
esac

exec "$@"
