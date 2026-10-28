-- Checks the route table in conf/conf.d against D-13 and LLD §18: only
-- /api/v1/* locations run the limiter, and health, docs, landing-page and
-- internal routes never do. Reads the files as text; nginx is not started.

local CONF_DIR = "conf/conf.d/"

--- Collect every location in a file with the text of its block.
local function locations(file)
  local handle = assert(io.open(CONF_DIR .. file, "r"))
  -- Comments may mention "location"; drop them before parsing.
  local text = handle:read("*a"):gsub("#[^\n]*", "")
  handle:close()

  local found = {}
  local position = 1
  while true do
    local start, head_end, matcher = text:find("location%s+([^{]-)%s*{", position)
    if not start then
      break
    end
    local depth, i = 1, head_end + 1
    while depth > 0 do
      local c = text:sub(i, i)
      if c == "{" then
        depth = depth + 1
      elseif c == "}" then
        depth = depth - 1
      end
      i = i + 1
    end
    found[matcher] = text:sub(head_end + 1, i - 2)
    position = i
  end
  return found
end

local function all_locations()
  local merged = {}
  for _, file in ipairs({ "routes.conf", "docs.conf", "health.conf", "server.conf" }) do
    for matcher, body in pairs(locations(file)) do
      merged[matcher] = body
    end
  end
  return merged
end

describe("gateway route table", function()
  local routes = all_locations()

  local function limited(matcher)
    local body = assert(routes[matcher], "missing location " .. matcher)
    return body:find("rate_limit()", 1, true) ~= nil
  end

  it("limits exactly the /api/v1/* locations", function()
    local limited_matchers = {}
    for matcher in pairs(routes) do
      if limited(matcher) then
        limited_matchers[#limited_matchers + 1] = matcher
      end
    end
    table.sort(limited_matchers)
    assert.same({
      "/api/v1/",
      "~ ^/api/v1/goals(?:/|$)",
      "~ ^/api/v1/transactions(?:/|$)",
    }, limited_matchers)
  end)

  it("never limits health, readiness, docs or the landing page", function()
    for _, matcher in ipairs({ "= /health", "= /ready", "= /health/goals", "= /ready/goals",
      "= /health/transactions", "= /ready/transactions", "= /",
      "~ ^/docs/goals/(?:swagger-ui(?:/.*)?|v3/api-docs(?:/.*)?)$",
      "~ ^/docs/transactions/(?:docs|docs/oauth2-redirect|openapi\\.json)$" }) do
      assert.is_false(limited(matcher), matcher)
    end
  end)

  it("blocks /internal/ ahead of any regular expression", function()
    assert.matches("not_found()", routes["^~ /internal/"], 1, true)
    assert.is_nil(routes["^~ /internal/"]:find("proxy_pass", 1, true))
  end)

  it("sends API routes to the right upstream with a 10-second read timeout", function()
    assert.matches("proxy_pass http://goal_service;", routes["~ ^/api/v1/goals(?:/|$)"], 1, true)
    assert.matches("proxy_pass http://transaction_service;",
      routes["~ ^/api/v1/transactions(?:/|$)"], 1, true)
    local handle = assert(io.open("conf/snippets/proxy.conf", "r"))
    local snippet = handle:read("*a")
    handle:close()
    assert.matches("proxy_read_timeout 10s;", snippet, 1, true)
    assert.matches("proxy_set_header X-Correlation-ID $correlation_id;", snippet, 1, true)
  end)

  it("does not route metrics endpoints", function()
    for matcher in pairs(routes) do
      assert.is_nil(matcher:find("metrics", 1, true), matcher)
      assert.is_nil(matcher:find("actuator", 1, true), matcher)
    end
  end)
end)
