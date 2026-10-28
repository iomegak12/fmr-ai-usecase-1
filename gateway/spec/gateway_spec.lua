local cjson = require("cjson")
local fake_ngx = require("support.fake_ngx")
local fake_redis = require("support.fake_redis")

local START = 1761550000

describe("kalash.gateway", function()
  local gateway, ngx, server

  local function env(values)
    return function(name)
      return values[name]
    end
  end

  before_each(function()
    ngx = fake_ngx.new({ now = START })
    _G.ngx = ngx
    for _, name in ipairs({ "kalash.gateway", "kalash.ratelimit", "kalash.store",
      "kalash.problem" }) do
      package.loaded[name] = nil
    end
    gateway = require("kalash.gateway")
    server = fake_redis.server()
  end)

  local function start(values, redis_opts)
    gateway.init(env(values or {}))
    gateway.init_worker((fake_redis.client_factory(server, redis_opts)))
  end

  describe("start-up", function()
    it("refuses to start with invalid settings", function()
      assert.has_error(function()
        gateway.init(env({ RATE_LIMIT_REQUESTS = "many" }))
      end)
    end)

    it("logs gateway_started once, from the first worker, with the warm-up end", function()
      start()
      local log = ngx.find_log("event=gateway_started")
      assert.same("notice", log.level)
      assert.same("event=gateway_started warmupSeconds=30 warmupEndsAt=2025-10-27T07:27:10.000Z "
        .. "limit=100 windowSeconds=60 redis=redis:6379", log.message)

      ngx.logs = {}
      ngx.clock = START + 1
      gateway.init_worker((fake_redis.client_factory(server)))
      assert.is_nil(ngx.find_log("event=gateway_started"))
    end)

    it("uses resty.redis when no client constructor is given", function()
      package.loaded["resty.redis"] = { new = function() return nil, "stub" end }
      gateway.init(env({ RATE_LIMIT_WARMUP_SECONDS = "0" }))
      gateway.init_worker()
      ngx.var.ratelimit_outcome = ""
      gateway.rate_limit()
      assert.same("fail_open", ngx.var.ratelimit_outcome)
      package.loaded["resty.redis"] = nil
    end)

    it("logs worker shutdown", function()
      gateway.exit_worker()
      assert.same("event=gateway_worker_stopped pid=4242 resources=redis_keepalive_pool",
        ngx.logs[1].message)
    end)
  end)

  describe("rate_limit", function()
    it("skips the limiter during warm-up and enforces it afterwards", function()
      start({ RATE_LIMIT_REQUESTS = "1" })
      gateway.rate_limit()
      assert.same("warmup", ngx.var.ratelimit_outcome)
      ngx.clock = START + 30
      gateway.rate_limit()
      assert.same("allowed", ngx.var.ratelimit_outcome)
      gateway.rate_limit()
      assert.same("rejected", ngx.var.ratelimit_outcome)
      assert.same(429, ngx.exited)
    end)
  end)

  describe("ready", function()
    it("reports UP when Redis answers", function()
      start()
      gateway.ready()
      assert.same(200, ngx.status)
      assert.same(200, ngx.exited)
      assert.same("application/json", ngx.header["Content-Type"])
      assert.same({ status = "UP", checks = { redis = "UP" } }, cjson.decode(ngx.body()))
    end)

    it("reports DEGRADED with HTTP 200 when Redis is down", function()
      start(nil, { connect_error = "connection refused" })
      gateway.ready()
      assert.same(200, ngx.status)
      assert.same({ status = "DEGRADED", checks = { redis = "DOWN" } },
        cjson.decode(ngx.body()))
      assert.same("warn", ngx.find_log("event=readiness_degraded").level)
    end)
  end)

  describe("routing errors", function()
    it("answers blocked and unknown paths with 404 Problem Details", function()
      ngx.var.uri = "/internal/v1/goals/1/balance-adjustments"
      gateway.not_found()
      assert.same(404, ngx.exited)
      local body = cjson.decode(ngx.body())
      assert.same("about:blank", body.type)
      assert.same("/internal/v1/goals/1/balance-adjustments", body.instance)
    end)

    it("answers an unreachable upstream with 502", function()
      gateway.upstream_error(502)
      assert.same(502, ngx.exited)
      assert.same("The upstream service is unavailable.", cjson.decode(ngx.body()).detail)
      assert.same("err", ngx.find_log("event=upstream_unavailable status=502").level)
    end)

    it("answers an upstream timeout with 504", function()
      ngx.var.upstream_connect_time = "0.001"
      gateway.upstream_error(504)
      assert.same(504, ngx.exited)
      assert.same("Gateway Timeout", cjson.decode(ngx.body()).title)
    end)

    it("answers a connect timeout as unavailable (502), not a slow response", function()
      ngx.var.upstream_connect_time = "-"
      gateway.upstream_error(504)
      assert.same(502, ngx.exited)
      assert.same("The upstream service is unavailable.", cjson.decode(ngx.body()).detail)
    end)
  end)
end)
