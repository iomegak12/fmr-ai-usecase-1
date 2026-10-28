--- Gateway settings read from the environment and validated once at start-up.
--
-- Implements plan Section 6 (configuration matrix) and D-10 to D-12: the
-- limiter's size, window, warm-up and Redis target come from environment
-- variables with the agreed defaults. Invalid values stop the gateway from
-- starting instead of silently falling back, matching the services' validated
-- settings.
-- @module kalash.config

local _M = {}

--- Defaults from the plan's configuration matrix.
_M.DEFAULTS = {
  REDIS_HOST = "redis",
  REDIS_PORT = 6379,
  REDIS_TIMEOUT_MS = 100,
  RATE_LIMIT_REQUESTS = 100,
  RATE_LIMIT_WINDOW_SECONDS = 60,
  RATE_LIMIT_WARMUP_SECONDS = 30,
}

-- Inclusive bounds; they reject typos (for example a window in milliseconds)
-- without restricting reasonable local tuning.
local BOUNDS = {
  REDIS_PORT = { 1, 65535 },
  REDIS_TIMEOUT_MS = { 1, 10000 },
  RATE_LIMIT_REQUESTS = { 1, 100000 },
  RATE_LIMIT_WINDOW_SECONDS = { 1, 86400 },
  RATE_LIMIT_WARMUP_SECONDS = { 0, 86400 },
}

--- Read one variable, treating unset and blank values as "use the default".
-- @param getenv function returning a string or nil for a variable name
-- @param name string environment variable name
-- @return string|nil trimmed value, or nil when unset or blank
local function read(getenv, name)
  local value = getenv(name)
  if value == nil then
    return nil
  end
  value = value:match("^%s*(.-)%s*$")
  if value == "" then
    return nil
  end
  return value
end

--- Read a bounded whole number.
-- @param getenv function environment reader
-- @param name string variable name with an entry in BOUNDS
-- @return number the parsed value or the default
-- @raise error naming the variable when the value is not a whole number in range
local function integer(getenv, name)
  local raw = read(getenv, name)
  if raw == nil then
    return _M.DEFAULTS[name]
  end
  local min, max = BOUNDS[name][1], BOUNDS[name][2]
  if not raw:match("^%d+$") then
    error(string.format("%s must be a whole number between %d and %d", name, min, max), 0)
  end
  local value = tonumber(raw)
  if value < min or value > max then
    error(string.format("%s must be a whole number between %d and %d", name, min, max), 0)
  end
  return value
end

--- Read the Redis host name or address.
-- @param getenv function environment reader
-- @return string host
-- @raise error when the value contains characters that cannot be a host
local function host(getenv)
  local raw = read(getenv, "REDIS_HOST")
  if raw == nil then
    return _M.DEFAULTS.REDIS_HOST
  end
  if #raw > 253 or not raw:match("^[%w%.%-:]+$") then
    error("REDIS_HOST must be a host name or IP address", 0)
  end
  return raw
end

--- Load and validate the gateway settings.
-- @param getenv function(name) returning a string or nil; defaults to os.getenv
-- @return table settings: requests, window_seconds, warmup_seconds and redis
--   (host, port, timeout_ms, keepalive_ms, pool_size)
-- @raise error with a message naming the invalid variable
function _M.load(getenv)
  getenv = getenv or os.getenv
  return {
    requests = integer(getenv, "RATE_LIMIT_REQUESTS"),
    window_seconds = integer(getenv, "RATE_LIMIT_WINDOW_SECONDS"),
    warmup_seconds = integer(getenv, "RATE_LIMIT_WARMUP_SECONDS"),
    redis = {
      host = host(getenv),
      port = integer(getenv, "REDIS_PORT"),
      timeout_ms = integer(getenv, "REDIS_TIMEOUT_MS"),
      keepalive_ms = 60000,
      pool_size = 64,
    },
  }
end

return _M
