--- Entry points called from the nginx configuration.
--
-- Wires the configuration, warm-up, Redis store and limiter together once
-- per worker, and implements the gateway's own endpoints:
--
-- * init / init_worker / exit_worker: lifecycle and start-up logging (D-11,
--   plan Section 7.5).
-- * rate_limit: the /api/v1/* access-phase limiter (D-10 to D-14).
-- * ready: gateway readiness, DEGRADED rather than failed when Redis is
--   unreachable because the limiter fails open (D-12, plan Section 7.2).
-- * not_found / upstream_error: Problem Details for routing failures,
--   including blocked /internal/ paths (LLD §18, §19).
-- @module kalash.gateway

local config_loader = require("kalash.config")
local problem = require("kalash.problem")
local ratelimit = require("kalash.ratelimit")
local store = require("kalash.store")
local warmup = require("kalash.warmup")

local _M = {}

--- Name of the lua_shared_dict holding the start time.
_M.DICT = "kalash_gateway"

local state = {}

--- Load and validate settings (init_by_lua, master process).
-- An invalid setting raises, which stops nginx from starting.
-- @param getenv function|nil environment reader; defaults to os.getenv
function _M.init(getenv)
  state.config = config_loader.load(getenv)
end

--- Prepare this worker (init_worker_by_lua).
-- Records the start time (first worker only), creates the Redis store and
-- the limiter, and logs gateway_started once with the warm-up end time.
-- @param redis_new function|nil resty.redis constructor (tests pass a double)
function _M.init_worker(redis_new)
  local config = state.config
  local dict = ngx.shared[_M.DICT]
  local first, started = warmup.record_start(dict, ngx.now())

  state.store = store.new(config.redis, redis_new or require("resty.redis").new, dict)
  state.limiter = ratelimit.new({
    config = config,
    store = state.store,
    now = ngx.now,
    in_warmup = function()
      return (warmup.active(dict, ngx.now(), config.warmup_seconds))
    end,
  })

  if first then
    ngx.log(ngx.NOTICE, "event=gateway_started warmupSeconds=", config.warmup_seconds,
      " warmupEndsAt=", problem.timestamp(started + config.warmup_seconds),
      " limit=", config.requests, " windowSeconds=", config.window_seconds,
      " redis=", config.redis.host, ":", config.redis.port)
  end
end

--- Log worker shutdown (exit_worker_by_lua). Pooled Redis connections are
-- closed by nginx when the worker exits.
function _M.exit_worker()
  ngx.log(ngx.NOTICE, "event=gateway_worker_stopped pid=", ngx.worker.pid(),
    " resources=redis_keepalive_pool")
end

--- Apply the rate limiter to the current /api/v1/* request.
function _M.rate_limit()
  return state.limiter:access()
end

--- Report gateway readiness. Always HTTP 200: UP when Redis answers, and
-- DEGRADED when it does not, because requests are still forwarded.
function _M.ready()
  local ok, err = state.store:ping()
  local status = ok and "UP" or "DEGRADED"
  if not ok then
    ngx.log(ngx.WARN, "event=readiness_degraded dependency=redis error=", tostring(err))
  end
  ngx.status = 200
  ngx.header["Content-Type"] = "application/json"
  ngx.header["Cache-Control"] = "no-store"
  ngx.print(string.format('{"status":"%s","checks":{"redis":"%s"}}', status,
    ok and "UP" or "DOWN"))
  return ngx.exit(200)
end

--- Answer an unrouted or blocked path with a 404 Problem Details.
function _M.not_found()
  return problem.send_routing_error(404, "No public route matches this path.")
end

--- Answer an upstream connection failure (502) or timeout (504).
-- nginx reports a connect timeout (for example a stopped container) as 504;
-- when no connection was ever established ($upstream_connect_time ends in
-- "-") the service is unavailable, so the answer is 502.
-- @param status number 502 or 504, as nginx reported it
function _M.upstream_error(status)
  if status == 504 and (ngx.var.upstream_connect_time or ""):match("%-%s*$") then
    status = 502
  end
  local detail = status == 504 and "The upstream service did not respond in time."
    or "The upstream service is unavailable."
  ngx.log(ngx.ERR, "event=upstream_unavailable status=", status,
    " path=", ngx.var.uri, " correlationId=", ngx.var.correlation_id)
  return problem.send_routing_error(status, detail)
end

return _M
