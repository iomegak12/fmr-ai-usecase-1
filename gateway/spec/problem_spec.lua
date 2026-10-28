local cjson = require("cjson")
local fake_ngx = require("support.fake_ngx")

describe("kalash.problem", function()
  local problem, ngx

  before_each(function()
    ngx = fake_ngx.new({ now = 1761550000.25, var = { uri = "/api/v1/goals/x" } })
    _G.ngx = ngx
    package.loaded["kalash.problem"] = nil
    problem = require("kalash.problem")
  end)

  describe("timestamp", function()
    it("formats UTC with milliseconds", function()
      assert.same("2025-10-27T07:26:40.250Z", problem.timestamp(1761550000.25))
      assert.same("1970-01-01T00:00:00.000Z", problem.timestamp(0))
    end)

    it("carries rounding into the next second", function()
      assert.same("1970-01-01T00:00:02.000Z", problem.timestamp(1.9996))
    end)
  end)

  describe("body", function()
    it("orders catalogue problems like the services and keeps slashes readable", function()
      local body = problem.body({ status = 429, code = "COMMON-429",
        title = "Too many requests, please retry later", detail = "Slow down.",
        instance = "/api/v1/goals", correlation_id = "abc", now = 0 })
      assert.same('{"type":"urn:kalash:error:COMMON-429",'
        .. '"title":"Too many requests, please retry later","status":429,'
        .. '"detail":"Slow down.","instance":"/api/v1/goals","errorCode":"COMMON-429",'
        .. '"correlationId":"abc","timestamp":"1970-01-01T00:00:00.000Z"}', body)
    end)

    it("uses about:blank and no errorCode for routing errors", function()
      local decoded = cjson.decode(problem.body({ status = 404, title = "Not Found",
        detail = "d", instance = "/internal/v1/goals/1", now = 0 }))
      assert.same("about:blank", decoded.type)
      assert.is_nil(decoded.errorCode)
      assert.same("", decoded.correlationId)
    end)

    it("escapes JSON-sensitive characters in values", function()
      local decoded = cjson.decode(problem.body({ status = 404, title = "Not Found",
        detail = 'quote " and \\', instance = "/x\n", correlation_id = "c", now = 0 }))
      assert.same('quote " and \\', decoded.detail)
      assert.same("/x\n", decoded.instance)
    end)
  end)

  describe("send", function()
    it("writes status, headers and body from the current request, then exits", function()
      problem.send({ status = 429, code = "COMMON-429", title = "t", detail = "d" },
        { ["Retry-After"] = "12" })
      assert.same(429, ngx.status)
      assert.same(429, ngx.exited)
      assert.same("application/problem+json", ngx.header["Content-Type"])
      assert.same("no-store", ngx.header["Cache-Control"])
      assert.same("12", ngx.header["Retry-After"])
      local decoded = cjson.decode(ngx.body())
      assert.same("/api/v1/goals/x", decoded.instance)
      assert.same("corr-123", decoded.correlationId)
      assert.same("2025-10-27T07:26:40.250Z", decoded.timestamp)
    end)

    for status, title in pairs({ [404] = "Not Found", [502] = "Bad Gateway",
      [504] = "Gateway Timeout", [500] = "Error" }) do
      it("titles routing error " .. status, function()
        problem.send_routing_error(status, "detail")
        local decoded = cjson.decode(ngx.body())
        assert.same(title, decoded.title)
        assert.same(status, decoded.status)
        assert.same(status, ngx.exited)
      end)
    end
  end)
end)
