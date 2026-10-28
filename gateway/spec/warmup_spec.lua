local fake_ngx = require("support.fake_ngx")
local warmup = require("kalash.warmup")

describe("kalash.warmup", function()
  local dict

  before_each(function()
    dict = fake_ngx.dict()
  end)

  it("records the start time once, for the first worker only", function()
    assert.same({ true, 1000 }, { warmup.record_start(dict, 1000) })
    assert.same({ false, 1000 }, { warmup.record_start(dict, 1005) })
    assert.same(1000, dict:get(warmup.KEY))
  end)

  it("falls back to now if the stored value vanished after a failed add", function()
    local broken = { add = function() return false end, get = function() return nil end }
    assert.same({ false, 7 }, { warmup.record_start(broken, 7) })
  end)

  it("is active from the start until start + seconds", function()
    warmup.record_start(dict, 1000)
    assert.same({ true, 1030 }, { warmup.active(dict, 1000, 30) })
    assert.same({ true, 1030 }, { warmup.active(dict, 1029.999, 30) })
  end)

  it("ends exactly at start + seconds", function()
    warmup.record_start(dict, 1000)
    assert.same({ false, 1030 }, { warmup.active(dict, 1030, 30) })
    assert.same({ false, 1030 }, { warmup.active(dict, 5000, 30) })
  end)

  it("is never active with a zero-second warm-up", function()
    warmup.record_start(dict, 1000)
    assert.is_false((warmup.active(dict, 1000, 0)))
  end)

  it("enforces limits when no start time is recorded", function()
    assert.same({ false }, { warmup.active(dict, 1000, 30) })
  end)
end)
