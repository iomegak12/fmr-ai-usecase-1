local config = require("kalash.config")

local function env(values)
  return function(name)
    return values[name]
  end
end

describe("kalash.config", function()
  it("uses the plan defaults when nothing is set", function()
    local c = config.load(env({}))
    assert.same(100, c.requests)
    assert.same(60, c.window_seconds)
    assert.same(30, c.warmup_seconds)
    assert.same({ host = "redis", port = 6379, timeout_ms = 100, keepalive_ms = 60000,
      pool_size = 64 }, c.redis)
  end)

  it("reads every variable from the environment", function()
    local c = config.load(env({
      RATE_LIMIT_REQUESTS = "5",
      RATE_LIMIT_WINDOW_SECONDS = "10",
      RATE_LIMIT_WARMUP_SECONDS = "0",
      REDIS_HOST = "10.0.0.5",
      REDIS_PORT = "6380",
      REDIS_TIMEOUT_MS = "250",
    }))
    assert.same(5, c.requests)
    assert.same(10, c.window_seconds)
    assert.same(0, c.warmup_seconds)
    assert.same("10.0.0.5", c.redis.host)
    assert.same(6380, c.redis.port)
    assert.same(250, c.redis.timeout_ms)
  end)

  it("treats blank values as unset and trims whitespace", function()
    local c = config.load(env({ RATE_LIMIT_REQUESTS = "  ", REDIS_HOST = " cache ",
      REDIS_PORT = " 6390 " }))
    assert.same(100, c.requests)
    assert.same("cache", c.redis.host)
    assert.same(6390, c.redis.port)
  end)

  it("defaults to os.getenv", function()
    assert.same(100, config.load().requests)
  end)

  for _, case in ipairs({
    { "RATE_LIMIT_REQUESTS", "abc" },
    { "RATE_LIMIT_REQUESTS", "0" },
    { "RATE_LIMIT_REQUESTS", "1.5" },
    { "RATE_LIMIT_REQUESTS", "-1" },
    { "RATE_LIMIT_WINDOW_SECONDS", "0" },
    { "RATE_LIMIT_WINDOW_SECONDS", "86401" },
    { "RATE_LIMIT_WARMUP_SECONDS", "x" },
    { "REDIS_PORT", "70000" },
    { "REDIS_TIMEOUT_MS", "0" },
  }) do
    it("rejects " .. case[1] .. "=" .. case[2], function()
      assert.has_error(function()
        config.load(env({ [case[1]] = case[2] }))
      end)
      local ok, err = pcall(config.load, env({ [case[1]] = case[2] }))
      assert.is_false(ok)
      assert.matches(case[1] .. " must be a whole number between", err, 1, true)
    end)
  end

  it("rejects a Redis host that could not be a host name", function()
    local ok, err = pcall(config.load, env({ REDIS_HOST = "redis;evil" }))
    assert.is_false(ok)
    assert.same("REDIS_HOST must be a host name or IP address", err)
    assert.is_false(pcall(config.load, env({ REDIS_HOST = string.rep("a", 254) })))
  end)
end)
