--- Per-IP sliding-window rate limiter for /api/v1/* (access phase).
--
-- Implements D-10 to D-15:
--
-- * D-10: counts each client IP ($remote_addr, D-15) in a Redis sliding-window
--   log; RATE_LIMIT_REQUESTS per RATE_LIMIT_WINDOW_SECONDS.
-- * D-11: during warm-up the request is neither limited nor counted.
-- * D-12: any Redis error or timeout forwards the request (fail open) and logs
--   ERROR with event=ratelimit_store_unavailable.
-- * D-14: a rejected request gets HTTP 429 Problem Details (COMMON-429) with
--   Retry-After; counted requests carry X-RateLimit-Limit, -Remaining and
--   -Reset (seconds until the oldest counted request leaves the window).
--
-- The outcome (warmup, allowed, rejected or fail_open) is stored in
-- $ratelimit_outcome for the JSON access log. Header values are stored in
-- $ratelimit_* variables, which the server configuration turns into headers
-- on every response, including upstream errors.
-- @module kalash.ratelimit

local problem = require("kalash.problem")

local _M = {}
local mt = { __index = _M }

--- Redis key prefix; the client IP is appended.
_M.KEY_PREFIX = "kalash:ratelimit:"

--- Create a limiter.
-- @param opts table with config (kalash.config settings), store
--   (kalash.store or a double with hit), in_warmup (function returning a
--   boolean) and now (function returning epoch seconds)
-- @return table limiter instance
function _M.new(opts)
  return setmetatable({
    config = opts.config,
    store = opts.store,
    in_warmup = opts.in_warmup,
    now = opts.now,
  }, mt)
end

--- Decide what to do with one request, without touching the response.
-- @param client_ip string rate-limit key ($remote_addr after real_ip)
-- @param request_id string unique per request; makes the Redis member unique
-- @return table decision: outcome ("warmup", "allowed", "rejected" or
--   "fail_open"); for counted requests limit, remaining and reset (seconds);
--   for fail_open the store error
function _M:decide(client_ip, request_id)
  if self.in_warmup() then
    return { outcome = "warmup" }
  end

  local limit = self.config.requests
  local now_ms = math.floor(self.now() * 1000)
  local result, err = self.store:hit(
    _M.KEY_PREFIX .. client_ip,
    string.format("%d", now_ms),
    string.format("%d", self.config.window_seconds * 1000),
    limit,
    string.format("%d:%s", now_ms, request_id)
  )
  if not result then
    return { outcome = "fail_open", error = err }
  end

  return {
    outcome = result.allowed and "allowed" or "rejected",
    limit = limit,
    remaining = result.remaining,
    reset = math.max(1, math.ceil((result.reset_ms - now_ms) / 1000)),
  }
end

--- Access-phase handler: record the outcome and reject when over the limit.
-- Returns normally for warm-up, allowed and fail-open requests so the proxy
-- continues; ends the request with 429 otherwise.
function _M:access()
  local var = ngx.var
  local decision = self:decide(var.remote_addr, var.request_id)
  var.ratelimit_outcome = decision.outcome

  if decision.outcome == "fail_open" then
    ngx.log(ngx.ERR, "event=ratelimit_store_unavailable outcome=fail_open clientIp=",
      var.remote_addr, " correlationId=", var.correlation_id,
      " error=", tostring(decision.error))
    return
  end
  if decision.outcome == "warmup" then
    return
  end

  var.ratelimit_limit = tostring(decision.limit)
  var.ratelimit_remaining = tostring(decision.remaining)
  var.ratelimit_reset = tostring(decision.reset)

  if decision.outcome == "rejected" then
    ngx.log(ngx.WARN, "event=ratelimit_rejected clientIp=", var.remote_addr,
      " correlationId=", var.correlation_id, " limit=", decision.limit,
      " windowSeconds=", self.config.window_seconds,
      " retryAfterSeconds=", decision.reset)
    local entry = problem.RATE_LIMITED
    return problem.send({
      status = entry.status,
      code = entry.code,
      title = entry.title,
      detail = string.format(
        "Limit of %d requests per %d seconds reached. Retry after %d seconds.",
        decision.limit, self.config.window_seconds, decision.reset),
    }, { ["Retry-After"] = tostring(decision.reset) })
  end
end

return _M
