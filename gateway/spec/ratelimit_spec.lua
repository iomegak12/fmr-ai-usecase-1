local cjson = require("cjson")
local fake_ngx = require("support.fake_ngx")
local fake_redis = require("support.fake_redis")

local START = 1761550000
local KEY = "kalash:ratelimit:203.0.113.7"

describe("kalash.ratelimit", function()
  local ratelimit, store, warmup, ngx, server, dict, limiter

  -- Builds the limiter the way kalash.gateway does, on top of the real store,
  -- the real Redis script (via the double) and the real warm-up check.
  local function build(opts)
    opts = opts or {}
    local config = { requests = opts.requests or 100, window_seconds = 60,
      warmup_seconds = opts.warmup or 0, redis = { host = "redis", port = 6379,
      timeout_ms = 100, keepalive_ms = 60000, pool_size = 64 } }
    local factory = fake_redis.client_factory(server, opts.redis)
    limiter = ratelimit.new({
      config = config,
      store = store.new(config.redis, factory, dict),
      now = ngx.now,
      in_warmup = function()
        return (warmup.active(dict, ngx.now(), config.warmup_seconds))
      end,
    })
    return limiter
  end

  -- Runs one request at the current fake time and returns what it produced.
  -- Like nginx's $request_id, every request gets a fresh ID.
  local sequence = 0
  local function request(ip)
    sequence = sequence + 1
    ngx.var.request_id = string.format("%032x", sequence)
    ngx.var.remote_addr = ip or "203.0.113.7"
    ngx.var.ratelimit_outcome, ngx.var.ratelimit_limit = "", ""
    ngx.var.ratelimit_remaining, ngx.var.ratelimit_reset = "", ""
    ngx.status, ngx.exited, ngx.output, ngx.header = 0, nil, {}, {}
    limiter:access()
    return {
      outcome = ngx.var.ratelimit_outcome,
      limit = ngx.var.ratelimit_limit,
      remaining = ngx.var.ratelimit_remaining,
      reset = ngx.var.ratelimit_reset,
      exited = ngx.exited,
    }
  end

  before_each(function()
    ngx = fake_ngx.new({ now = START })
    _G.ngx = ngx
    for _, name in ipairs({ "kalash.ratelimit", "kalash.store", "kalash.problem" }) do
      package.loaded[name] = nil
    end
    ratelimit = require("kalash.ratelimit")
    store = require("kalash.store")
    warmup = require("kalash.warmup")
    server = fake_redis.server()
    dict = ngx.shared.kalash_gateway
    warmup.record_start(dict, START)
  end)

  it("allows requests under the limit and sets the rate-limit headers", function()
    build()
    local r = request()
    assert.same({ outcome = "allowed", limit = "100", remaining = "99", reset = "60" }, {
      outcome = r.outcome, limit = r.limit, remaining = r.remaining, reset = r.reset })
    assert.is_nil(r.exited)
  end)

  it("allows exactly 100 requests in the window", function()
    build()
    local last
    for _ = 1, 100 do
      ngx.clock = ngx.clock + 0.1
      last = request()
      assert.same("allowed", last.outcome)
    end
    assert.same("0", last.remaining)
    assert.same(100, server.count(KEY))
  end)

  it("rejects request 101 with a 429 Problem Details and Retry-After", function()
    build()
    for _ = 1, 100 do
      request()
      ngx.clock = ngx.clock + 0.25
    end
    local r = request()
    assert.same("rejected", r.outcome)
    assert.same(429, r.exited)
    assert.same(429, ngx.status)
    assert.same({ "100", "0" }, { r.limit, r.remaining })
    -- The first request (at START) leaves the window at START + 60; now is START + 25.
    assert.same("35", r.reset)
    assert.same("35", ngx.header["Retry-After"])
    assert.same("application/problem+json", ngx.header["Content-Type"])
    local body = cjson.decode(ngx.body())
    assert.same("COMMON-429", body.errorCode)
    assert.same("urn:kalash:error:COMMON-429", body.type)
    assert.same("Too many requests, please retry later", body.title)
    assert.same("Limit of 100 requests per 60 seconds reached. Retry after 35 seconds.",
      body.detail)
    assert.same("corr-123", body.correlationId)
    assert.same(100, server.count(KEY))
    local log = ngx.find_log("event=ratelimit_rejected")
    assert.same("warn", log.level)
    assert.matches("clientIp=203.0.113.7 correlationId=corr-123", log.message, 1, true)
  end)

  it("slides: capacity returns once the oldest request is 60 seconds old", function()
    build({ requests = 2 })
    request()
    ngx.clock = START + 10
    request()
    ngx.clock = START + 59.999
    assert.same("rejected", request().outcome)
    ngx.clock = START + 60
    local r = request()
    assert.same("allowed", r.outcome)
    assert.same("0", r.remaining)
    assert.same("10", r.reset)
  end)

  it("limits each client IP separately", function()
    build({ requests = 1 })
    assert.same("allowed", request("203.0.113.7").outcome)
    assert.same("rejected", request("203.0.113.7").outcome)
    assert.same("allowed", request("2001:db8::1").outcome)
  end)

  it("neither limits nor counts during warm-up", function()
    build({ warmup = 30 })
    for _ = 1, 150 do
      local r = request()
      assert.same("warmup", r.outcome)
      assert.same("", r.limit)
      assert.is_nil(r.exited)
    end
    assert.same(0, server.count(KEY))
    assert.same(0, #server.calls)
  end)

  it("starts limiting the moment warm-up ends, from an empty window", function()
    build({ warmup = 30, requests = 2 })
    ngx.clock = START + 29.999
    for _ = 1, 10 do
      request()
    end
    ngx.clock = START + 30
    assert.same("allowed", request().outcome)
    assert.same("allowed", request().outcome)
    assert.same("rejected", request().outcome)
  end)

  it("fails open and logs ERROR when Redis is unavailable", function()
    build({ redis = { connect_error = "connection refused" } })
    local r = request()
    assert.same("fail_open", r.outcome)
    assert.is_nil(r.exited)
    assert.same("", r.limit)
    local log = ngx.find_log("event=ratelimit_store_unavailable")
    assert.same("err", log.level)
    assert.matches("outcome=fail_open clientIp=203.0.113.7 correlationId=corr-123 "
      .. "error=connect: connection refused", log.message, 1, true)
  end)

  it("keeps failing open, and logging, while the store backs off", function()
    build({ redis = { connect_error = "connection refused" } })
    request()
    local r = request()
    assert.same("fail_open", r.outcome)
    assert.is_nil(r.exited)
    local errors = 0
    for _, entry in ipairs(ngx.logs) do
      if entry.message:find("event=ratelimit_store_unavailable", 1, true) then
        errors = errors + 1
      end
    end
    assert.same(2, errors)
    assert.truthy(ngx.find_log("error=skipped after recent failure"))
  end)

  it("fails open on a Redis timeout during the script", function()
    server.script_loaded = true
    build({ redis = { script_error = "timeout" } })
    assert.same("fail_open", request().outcome)
    assert.truthy(ngx.find_log("error=script: timeout"))
  end)

  it("counts every request in the same millisecond separately", function()
    build({ requests = 2 })
    assert.same("allowed", request().outcome)
    assert.same("allowed", request().outcome)
    assert.same("rejected", request().outcome)
    assert.same(2, server.count(KEY))
  end)
end)
