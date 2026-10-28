--- RFC 9457 Problem Details responses produced by the gateway itself.
--
-- Implements D-14 and plan Section 7.1 (COMMON-429) and keeps gateway errors
-- in the same shape as the services (LLD §21.1): type, title, status, detail,
-- instance, errorCode (catalogued errors only), correlationId and a UTC
-- timestamp. Routing errors that have no catalogue code (404, 502, 504) use
-- type "about:blank", as the services do for framework errors.
-- @module kalash.problem

local json = require("cjson.safe").new()
json.encode_escape_forward_slash(false)

local _M = {}

--- Catalogue entry for the gateway rate limiter (plan Section 7.1).
_M.RATE_LIMITED = {
  status = 429,
  code = "COMMON-429",
  title = "Too many requests, please retry later",
}

--- Format epoch seconds as an ISO 8601 UTC timestamp with milliseconds.
-- @param now number epoch seconds, possibly fractional
-- @return string for example "2026-10-27T06:40:00.123Z"
function _M.timestamp(now)
  local seconds = math.floor(now)
  local millis = math.floor((now - seconds) * 1000 + 0.5)
  if millis >= 1000 then
    seconds, millis = seconds + 1, 0
  end
  return os.date("!%Y-%m-%dT%H:%M:%S", seconds) .. string.format(".%03dZ", millis)
end

--- Build a Problem Details document with a stable field order.
-- @param p table status, title, detail, instance, correlation_id and now
--   (epoch seconds); optional code (catalogue error code)
-- @return string JSON body
function _M.body(p)
  local fields = {
    { "type", p.code and ("urn:kalash:error:" .. p.code) or "about:blank" },
    { "title", p.title },
    { "status", p.status },
    { "detail", p.detail },
    { "instance", p.instance },
  }
  if p.code then
    fields[#fields + 1] = { "errorCode", p.code }
  end
  fields[#fields + 1] = { "correlationId", p.correlation_id or "" }
  fields[#fields + 1] = { "timestamp", _M.timestamp(p.now) }

  local parts = {}
  for i, field in ipairs(fields) do
    parts[i] = json.encode(field[1]) .. ":" .. json.encode(field[2])
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

--- Send a Problem Details response and finish the request.
-- Works in the access and content phases. Extra headers (for example
-- Retry-After) are set before the body is written.
-- @param p table fields accepted by body(), except instance, correlation_id
--   and now, which are taken from the current request
-- @param headers table|nil extra response headers
-- @return nothing; ends the request with ngx.exit
function _M.send(p, headers)
  p.instance = ngx.var.uri
  p.correlation_id = ngx.var.correlation_id
  p.now = ngx.now()
  local body = _M.body(p)

  ngx.status = p.status
  ngx.header["Content-Type"] = "application/problem+json"
  ngx.header["Cache-Control"] = "no-store"
  for name, value in pairs(headers or {}) do
    ngx.header[name] = value
  end
  ngx.print(body)
  return ngx.exit(p.status)
end

--- Send a routing error without a catalogue code.
-- @param status number HTTP status (404, 502 or 504)
-- @param detail string human-readable explanation
function _M.send_routing_error(status, detail)
  local titles = { [404] = "Not Found", [502] = "Bad Gateway", [504] = "Gateway Timeout" }
  return _M.send({ status = status, title = titles[status] or "Error", detail = detail })
end

return _M
