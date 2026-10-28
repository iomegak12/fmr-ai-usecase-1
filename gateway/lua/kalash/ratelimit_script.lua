--- Atomic sliding-window log script executed inside Redis.
--
-- Implements D-10: one sorted set per client IP holds one member per counted
-- request, scored by its arrival time in milliseconds. In a single atomic step
-- the script:
--
-- 1. removes members at or before now - window (outside the rolling window);
-- 2. counts the remaining members;
-- 3. adds this request with a unique member only when the count is under the
--    limit, and refreshes the key's expiry to one window;
-- 4. returns { allowed (1 or 0), remaining, reset_ms }, where reset_ms is the
--    epoch millisecond at which the oldest counted request leaves the window.
--
-- KEYS[1] is the client key. ARGV is now_ms, window_ms, limit and member.
-- The script runs in Redis's own Lua sandbox, not in OpenResty.
-- @module kalash.ratelimit_script

return [[
local key = KEYS[1]
local now = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local limit = tonumber(ARGV[3])
local member = ARGV[4]

redis.call('ZREMRANGEBYSCORE', key, '-inf', now - window)
local count = redis.call('ZCARD', key)
local allowed = 0
if count < limit then
  redis.call('ZADD', key, now, member)
  redis.call('PEXPIRE', key, window)
  count = count + 1
  allowed = 1
end

local reset = now + window
local oldest = redis.call('ZRANGE', key, 0, 0, 'WITHSCORES')
if oldest[2] then
  reset = tonumber(oldest[2]) + window
end
return { allowed, math.max(limit - count, 0), reset }
]]
