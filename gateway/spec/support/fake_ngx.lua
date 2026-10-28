--- Minimal stand-in for the OpenResty `ngx` API used by lua/kalash.
-- Records logs, output, headers and the exit code so specs can assert on
-- them without running nginx.
-- @module support.fake_ngx

local M = {}

--- Create a shared-dictionary double with add/get semantics.
-- @return table dictionary
function M.dict()
  local dict = { data = {} }
  function dict.add(self, key, value)
    if self.data[key] ~= nil then
      return false, "exists"
    end
    self.data[key] = value
    return true
  end
  function dict.get(self, key)
    return self.data[key]
  end
  function dict.set(self, key, value)
    self.data[key] = value
    return true
  end
  function dict.delete(self, key)
    self.data[key] = nil
  end
  return dict
end

--- Create a fake ngx.
-- @param opts table|nil now (epoch seconds) and var overrides
-- @return table fake ngx
function M.new(opts)
  opts = opts or {}
  local ngx = {
    OK = 0,
    HTTP_OK = 200,
    NOTICE = "notice",
    WARN = "warn",
    ERR = "err",
    var = {
      remote_addr = "203.0.113.7",
      request_id = "0123456789abcdef0123456789abcdef",
      correlation_id = "corr-123",
      uri = "/api/v1/goals",
    },
    header = {},
    status = 0,
    logs = {},
    output = {},
    exited = nil,
    clock = opts.now or 1761550000.25,
    shared = { kalash_gateway = M.dict() },
    worker = {
      pid = function()
        return 4242
      end,
    },
  }
  for name, value in pairs(opts.var or {}) do
    ngx.var[name] = value
  end

  function ngx.now()
    return ngx.clock
  end
  function ngx.log(level, ...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    ngx.logs[#ngx.logs + 1] = { level = level, message = table.concat(parts) }
  end
  function ngx.print(text)
    ngx.output[#ngx.output + 1] = text
  end
  function ngx.exit(code)
    ngx.exited = code
    return code
  end
  function ngx.sha1_bin()
    return string.rep("\171", 20)
  end

  --- Return the response body written so far.
  function ngx.body()
    return table.concat(ngx.output)
  end

  --- Return the first log entry whose message contains text, or nil.
  function ngx.find_log(text)
    for _, entry in ipairs(ngx.logs) do
      if entry.message:find(text, 1, true) then
        return entry
      end
    end
    return nil
  end

  return ngx
end

return M
