--- Start-time capture and warm-up check for the rate limiter.
--
-- Implements D-11: for the first RATE_LIMIT_WARMUP_SECONDS after the gateway
-- starts, requests are neither limited nor counted. The start time lives in a
-- shared dictionary so every worker agrees on it. Only the first worker to
-- start writes it, and a configuration reload (HUP) keeps the existing value,
-- so only a real restart opens a new warm-up window (plan risk R-02).
-- @module kalash.warmup

local _M = {}

--- Shared-dictionary key holding the start time in epoch seconds.
_M.KEY = "gateway_started_at"

--- Record the gateway start time unless another worker already has.
-- @param dict table shared dictionary (ngx.shared.*) with add/get
-- @param now number current epoch time in seconds
-- @return boolean true when this call recorded the time (first worker)
-- @return number the recorded start time
function _M.record_start(dict, now)
  local added = dict:add(_M.KEY, now)
  if added then
    return true, now
  end
  return false, dict:get(_M.KEY) or now
end

--- Report whether the warm-up period is still running.
-- A missing start time counts as "warm-up over", so the limiter enforces
-- limits rather than staying open indefinitely.
-- @param dict table shared dictionary with get
-- @param now number current epoch time in seconds
-- @param seconds number warm-up length in seconds
-- @return boolean true while now is before start + seconds
-- @return number|nil epoch seconds when warm-up ends, if a start is recorded
function _M.active(dict, now, seconds)
  local started = dict:get(_M.KEY)
  if not started then
    return false, nil
  end
  local ends_at = started + seconds
  return now < ends_at, ends_at
end

return _M
