--- Redis access for the rate limiter and gateway readiness.
--
-- Implements the store side of D-10 and D-12: every call uses short connect,
-- send and read timeouts (REDIS_TIMEOUT_MS) and returns healthy connections to
-- a per-worker keepalive pool. Failures are returned, never raised, so the
-- caller can fail open. The limiter script is sent with EVALSHA and re-sent
-- with EVAL only when Redis reports NOSCRIPT (for example after a restart).
--
-- After a failure, hit() skips Redis for RETRY_INTERVAL seconds and fails
-- immediately. The back-off is kept in the shared dictionary, so it applies
-- to every worker, and when it expires the first request extends it before
-- probing Redis, so only that one request can wait for a timeout. An outage
-- therefore slows at most one request per interval (a DNS lookup for a
-- missing host can take resolver_timeout). ping() always contacts Redis,
-- and its success ends the back-off early.
-- @module kalash.store

local SCRIPT = require("kalash.ratelimit_script")

local _M = {}
local mt = { __index = _M }

--- Seconds hit() skips Redis after a failure. Longer than the slowest probe
-- (resolver_timeout plus the Redis timeouts), so probes never overlap.
_M.RETRY_INTERVAL = 5

--- Shared-dictionary keys for the back-off state.
_M.DOWN_UNTIL_KEY = "redis_down_until"
_M.LAST_ERROR_KEY = "redis_last_error"

--- Hex-encode a binary string.
-- @param bin string raw bytes
-- @return string lowercase hexadecimal
local function to_hex(bin)
  return (bin:gsub(".", function(c)
    return string.format("%02x", c:byte())
  end))
end

--- Create a store.
-- @param redis_config table host, port, timeout_ms, keepalive_ms and pool_size
-- @param redis_new function returning a new resty.redis client
-- @param dict table shared dictionary (get, set, delete) for the back-off
-- @return table store instance
function _M.new(redis_config, redis_new, dict)
  return setmetatable({
    config = redis_config,
    redis_new = redis_new,
    dict = dict,
    script_sha = to_hex(ngx.sha1_bin(SCRIPT)),
  }, mt)
end

--- Open a connection with the configured timeouts.
-- @return table|nil connected client
-- @return string|nil error message
function _M:connect()
  local red, err = self.redis_new()
  if not red then
    return nil, "client: " .. tostring(err)
  end
  local timeout = self.config.timeout_ms
  red:set_timeouts(timeout, timeout, timeout)
  local ok, conn_err = red:connect(self.config.host, self.config.port)
  if not ok then
    return nil, "connect: " .. tostring(conn_err)
  end
  return red
end

--- Return a healthy connection to the pool, closing it if that fails.
-- @param red table connected client
function _M:release(red)
  local ok = red:set_keepalive(self.config.keepalive_ms, self.config.pool_size)
  if not ok then
    red:close()
  end
end

--- Count one request against a client's sliding window.
-- @param key string Redis key for the client
-- @param now_ms number current epoch time in milliseconds
-- @param window_ms number window length in milliseconds
-- @param limit number maximum requests in the window
-- @param member string unique member for this request
-- @return table|nil { allowed = boolean, remaining = number, reset_ms = number }
-- @return string|nil error message when Redis failed, replied unexpectedly or
--   is being skipped after a recent failure
function _M:hit(key, now_ms, window_ms, limit, member)
  local dict = self.dict
  local down_until = dict:get(_M.DOWN_UNTIL_KEY)
  if down_until then
    if ngx.now() < down_until then
      return nil, "skipped after recent failure ("
        .. tostring(dict:get(_M.LAST_ERROR_KEY)) .. ")"
    end
    -- This request probes Redis; the others keep skipping meanwhile.
    dict:set(_M.DOWN_UNTIL_KEY, ngx.now() + _M.RETRY_INTERVAL)
  end

  local result, err = self:eval_window(key, now_ms, window_ms, limit, member)
  if not result then
    dict:set(_M.DOWN_UNTIL_KEY, ngx.now() + _M.RETRY_INTERVAL)
    dict:set(_M.LAST_ERROR_KEY, err)
  elseif down_until then
    dict:delete(_M.DOWN_UNTIL_KEY)
  end
  return result, err
end

--- Run the limiter script once, without back-off handling.
-- @param key string Redis key for the client
-- @param now_ms number current epoch time in milliseconds
-- @param window_ms number window length in milliseconds
-- @param limit number maximum requests in the window
-- @param member string unique member for this request
-- @return table|nil decision, as for hit()
-- @return string|nil error message
function _M:eval_window(key, now_ms, window_ms, limit, member)
  local red, err = self:connect()
  if not red then
    return nil, err
  end
  local res
  res, err = red:evalsha(self.script_sha, 1, key, now_ms, window_ms, limit, member)
  if not res and err and err:find("NOSCRIPT", 1, true) then
    res, err = red:eval(SCRIPT, 1, key, now_ms, window_ms, limit, member)
  end
  if not res then
    red:close()
    return nil, "script: " .. tostring(err)
  end
  if type(res) ~= "table" or type(res[1]) ~= "number" or type(res[2]) ~= "number"
      or type(res[3]) ~= "number" then
    red:close()
    return nil, "script: unexpected reply"
  end
  self:release(red)
  return { allowed = res[1] == 1, remaining = res[2], reset_ms = res[3] }
end

--- Check that Redis answers PING.
-- @return boolean true when Redis replied PONG
-- @return string|nil error message otherwise
function _M:ping()
  local red, err = self:connect()
  if not red then
    return false, err
  end
  local res
  res, err = red:ping()
  if res ~= "PONG" then
    red:close()
    return false, "ping: " .. tostring(err or res)
  end
  self:release(red)
  self.dict:delete(_M.DOWN_UNTIL_KEY)
  return true
end

return _M
