local fake_redis = require("support.fake_redis")
local SCRIPT = require("kalash.ratelimit_script")

local KEY = "kalash:ratelimit:203.0.113.7"
local WINDOW = 60000

describe("kalash.ratelimit_script (run against the Redis double)", function()
  local server

  local function hit(now, limit, member)
    return server.run_script(SCRIPT, { KEY }, { now, WINDOW, limit or 100, member or ("m" .. now) })
  end

  before_each(function()
    server = fake_redis.server()
  end)

  it("counts the first request and reports the full window as reset time", function()
    assert.same({ 1, 99, 1000 + WINDOW }, hit(1000))
    assert.same(1, server.count(KEY))
    assert.same(WINDOW, server.expiry[KEY])
  end)

  it("allows exactly the limit, then rejects without counting", function()
    for i = 1, 100 do
      local result = hit(1000 + i, 100, "req" .. i)
      assert.same(1, result[1])
      assert.same(100 - i, result[2])
    end
    assert.same({ 0, 0, 1001 + WINDOW }, hit(1200, 100, "req101"))
    assert.same(100, server.count(KEY))
  end)

  it("keeps requests with the same millisecond apart by member", function()
    hit(1000, 100, "a")
    hit(1000, 100, "b")
    assert.same(2, server.count(KEY))
  end)

  it("slides: a request leaves the window exactly window ms after it arrived", function()
    hit(1000, 2, "first")
    hit(2000, 2, "second")
    assert.same(0, hit(1000 + WINDOW - 1, 2, "early")[1])
    local result = hit(1000 + WINDOW, 2, "on-time")
    assert.same(1, result[1])
    assert.same(0, result[2])
    assert.same(2000 + WINDOW, result[3])
    assert.same(2, server.count(KEY))
  end)

  it("frees the whole window once every request is older than the window", function()
    for i = 1, 3 do
      hit(i, 3, "r" .. i)
    end
    assert.same({ 1, 2, 10000 + 2 * WINDOW }, hit(10000 + WINDOW, 3, "later"))
    assert.same(1, server.count(KEY))
  end)

  it("never reports negative remaining capacity after the limit is lowered", function()
    for i = 1, 5 do
      hit(1000 + i, 10, "r" .. i)
    end
    assert.same({ 0, 0, 1001 + WINDOW }, hit(1100, 3, "x"))
  end)

  it("keeps clients apart by key", function()
    hit(1000, 1, "a")
    local other = server.run_script(SCRIPT, { "kalash:ratelimit:198.51.100.1" },
      { 1001, WINDOW, 1, "b" })
    assert.same(1, other[1])
  end)
end)
