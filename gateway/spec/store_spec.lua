local fake_ngx = require("support.fake_ngx")
local fake_redis = require("support.fake_redis")

local CONFIG = { host = "redis", port = 6379, timeout_ms = 100, keepalive_ms = 60000,
  pool_size = 64 }

describe("kalash.store", function()
  local store, server, dict

  before_each(function()
    _G.ngx = fake_ngx.new()
    package.loaded["kalash.store"] = nil
    store = require("kalash.store")
    server = fake_redis.server()
    dict = fake_ngx.dict()
  end)

  -- Stores created in one test share the dictionary, like nginx workers.
  local function new_store(opts)
    local factory, log = fake_redis.client_factory(server, opts)
    return store.new(CONFIG, factory, dict), log
  end

  it("hashes the script for EVALSHA as lowercase hex", function()
    assert.same(string.rep("ab", 20), new_store().script_sha)
  end)

  it("loads the script with EVAL after NOSCRIPT, then uses EVALSHA", function()
    local s, log = new_store()
    local first = s:hit("k", "1000", "60000", 100, "m1")
    assert.same({ allowed = true, remaining = 99, reset_ms = 61000 }, first)
    assert.same(1, log.eval)
    s:hit("k", "1001", "60000", 100, "m2")
    assert.same(2, log.evalsha)
    assert.same(1, log.eval)
    assert.same(string.rep("ab", 20), log.sha)
  end)

  it("applies the configured timeouts and target, and pools healthy connections", function()
    local s, log = new_store()
    s:hit("k", "1000", "60000", 100, "m")
    assert.same({ 100, 100, 100 }, log.timeouts)
    assert.same("redis:6379", log.target)
    assert.same(1, log.keepalives)
    assert.same(0, log.closes)
  end)

  it("reports a rejection from the script", function()
    local s = new_store()
    s:hit("k", "1000", "60000", 1, "a")
    assert.same({ allowed = false, remaining = 0, reset_ms = 61000 },
      s:hit("k", "1001", "60000", 1, "b"))
  end)

  it("returns an error when the client cannot be created", function()
    local s = new_store({ new_error = "no memory" })
    assert.same({ nil, "client: no memory" }, { s:hit("k", "1", "2", 3, "m") })
  end)

  it("returns an error when Redis cannot be reached", function()
    local s, log = new_store({ connect_error = "connection refused" })
    assert.same({ nil, "connect: connection refused" }, { s:hit("k", "1", "2", 3, "m") })
    assert.same(0, log.keepalives)
  end)

  it("closes the connection on a script error or timeout", function()
    server.script_loaded = true
    local s, log = new_store({ script_error = "timeout" })
    assert.same({ nil, "script: timeout" }, { s:hit("k", "1", "2", 3, "m") })
    assert.same(1, log.closes)
  end)

  it("rejects an unexpected reply shape", function()
    server.script_loaded = true
    local s, log = new_store({ reply = { 1, "x" } })
    assert.same({ nil, "script: unexpected reply" }, { s:hit("k", "1", "2", 3, "m") })
    assert.same(1, log.closes)
    dict = fake_ngx.dict()
    s = new_store({ reply = "OK" })
    assert.same({ nil, "script: unexpected reply" }, { s:hit("k", "1", "2", 3, "m") })
  end)

  it("closes a connection the pool refuses", function()
    local s, log = new_store({ keepalive_error = "closed" })
    assert.truthy(s:hit("k", "1000", "60000", 100, "m"))
    assert.same(1, log.closes)
  end)

  describe("back-off after a failure", function()
    it("skips Redis for the retry interval, then tries again", function()
      local s, log = new_store({ connect_error = "timeout" })
      local failed_at = ngx.clock
      assert.same({ nil, "connect: timeout" }, { s:hit("k", "1", "2", 3, "m") })
      ngx.clock = failed_at + store.RETRY_INTERVAL - 0.001
      assert.same({ nil, "skipped after recent failure (connect: timeout)" },
        { s:hit("k", "1", "2", 3, "m") })
      assert.same(1, log.connects)
      ngx.clock = failed_at + store.RETRY_INTERVAL
      s:hit("k", "1", "2", 3, "m")
      assert.same(2, log.connects)
    end)

    it("applies to every worker sharing the dictionary", function()
      local first = new_store({ connect_error = "timeout" })
      local other, other_log = new_store()
      first:hit("k", "1", "2", 3, "m")
      assert.is_nil((other:hit("k", "1", "2", 3, "m")))
      assert.same(0, other_log.connects)
    end)

    it("lets only one request probe once the interval expires", function()
      local probing, other_result
      local other = new_store()
      local s = new_store({
        connect_error = "timeout",
        on_connect = function()
          if probing then
            other_result = { other:hit("k", "1", "2", 3, "concurrent") }
          end
        end,
      })
      s:hit("k", "1", "2", 3, "m")
      ngx.clock = ngx.clock + store.RETRY_INTERVAL
      probing = true
      s:hit("k", "1", "2", 3, "probe")
      assert.is_nil(other_result[1])
      assert.matches("^skipped after recent failure", other_result[2])
    end)

    it("is cleared by the next success", function()
      local opts = { connect_error = "timeout" }
      local s = new_store(opts)
      s:hit("k", "1000", "60000", 100, "a")
      opts.connect_error = nil
      ngx.clock = ngx.clock + store.RETRY_INTERVAL
      assert.truthy(s:hit("k", "1000", "60000", 100, "b"))
      assert.is_nil(dict:get(store.DOWN_UNTIL_KEY))
    end)

    it("is ended early by a successful ping", function()
      local opts = { connect_error = "timeout" }
      local s, log = new_store(opts)
      s:hit("k", "1000", "60000", 100, "a")
      opts.connect_error = nil
      assert.is_true((s:ping()))
      assert.truthy(s:hit("k", "1000", "60000", 100, "b"))
      assert.same(3, log.connects)
    end)
  end)

  it("pings Redis", function()
    local s, log = new_store()
    assert.same({ true }, { s:ping() })
    assert.same(1, log.keepalives)
  end)

  it("reports ping failures without raising", function()
    assert.same({ false, "connect: timeout" }, { new_store({ connect_error = "timeout" }):ping() })
    local s, log = new_store({ ping_error = "LOADING" })
    assert.same({ false, "ping: LOADING" }, { s:ping() })
    assert.same(1, log.closes)
  end)
end)
