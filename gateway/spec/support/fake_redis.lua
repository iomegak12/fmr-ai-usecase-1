--- In-memory Redis double that runs the real limiter script.
--
-- server() implements just the sorted-set commands the script uses and
-- executes Lua scripts in a sandbox with redis.call, KEYS and ARGV, the way
-- Redis does (arguments as strings, returned numbers truncated to integers).
-- client_factory() returns a resty.redis-like constructor for kalash.store.
-- @module support.fake_redis

local M = {}

--- Create a Redis server double.
-- @return table server with call, run_script and zsets
function M.server()
  local server = { zsets = {}, expiry = {}, script_loaded = false, calls = {} }

  local function sorted(key)
    local list = {}
    for member, score in pairs(server.zsets[key] or {}) do
      list[#list + 1] = { member = member, score = score }
    end
    table.sort(list, function(a, b)
      if a.score == b.score then
        return a.member < b.member
      end
      return a.score < b.score
    end)
    return list
  end

  --- Execute one command.
  function server.call(cmd, key, ...)
    local args = { ... }
    server.calls[#server.calls + 1] = cmd
    if cmd == "ZREMRANGEBYSCORE" then
      local min = args[1] == "-inf" and -math.huge or tonumber(args[1])
      local max = tonumber(args[2])
      local removed = 0
      for member, score in pairs(server.zsets[key] or {}) do
        if score >= min and score <= max then
          server.zsets[key][member] = nil
          removed = removed + 1
        end
      end
      return removed
    elseif cmd == "ZCARD" then
      return #sorted(key)
    elseif cmd == "ZADD" then
      server.zsets[key] = server.zsets[key] or {}
      server.zsets[key][args[2]] = tonumber(args[1])
      return 1
    elseif cmd == "PEXPIRE" then
      server.expiry[key] = tonumber(args[1])
      return 1
    elseif cmd == "ZRANGE" then
      local list = sorted(key)
      local first = list[tonumber(args[1]) + 1]
      if not first then
        return {}
      end
      return { first.member, tostring(first.score) }
    end
    error("unsupported command " .. cmd)
  end

  --- Run a script the way EVAL does.
  -- @param source string script text
  -- @param keys table KEYS
  -- @param argv table ARGV (converted to strings)
  -- @return any the script result with numbers truncated to integers
  function server.run_script(source, keys, argv)
    local strings = {}
    for i, value in ipairs(argv) do
      strings[i] = tostring(value)
    end
    local env = {
      KEYS = keys,
      ARGV = strings,
      tonumber = tonumber,
      math = math,
      redis = {
        call = function(...)
          return server.call(...)
        end,
      },
    }
    local fn = assert(loadstring(source, "=ratelimit_script"))
    setfenv(fn, env)
    local result = fn()
    if type(result) == "table" then
      for i, value in ipairs(result) do
        if type(value) == "number" then
          result[i] = value >= 0 and math.floor(value) or math.ceil(value)
        end
      end
    end
    return result
  end

  --- Return the number of members stored for key.
  function server.count(key)
    return #sorted(key)
  end

  return server
end

--- Create a resty.redis-like constructor bound to a server.
-- @param server table from server()
-- @param opts table|nil failure switches: new_error, connect_error,
--   script_error, reply (override), ping_error, keepalive_error; and
--   on_connect, a hook called during connect
-- @return function constructor returning a client
-- @return table log of client activity (connects, keepalives, closes, timeouts)
function M.client_factory(server, opts)
  opts = opts or {}
  local log = { connects = 0, keepalives = 0, closes = 0, evalsha = 0, eval = 0 }

  local function new()
    if opts.new_error then
      return nil, opts.new_error
    end
    local client = {}
    function client.set_timeouts(_, connect, send, read)
      log.timeouts = { connect, send, read }
    end
    function client.connect(_, host, port)
      log.connects = log.connects + 1
      log.target = host .. ":" .. tostring(port)
      if opts.on_connect then
        opts.on_connect()
      end
      if opts.connect_error then
        return nil, opts.connect_error
      end
      return 1
    end
    local function run(source, key, ...)
      if opts.script_error then
        return nil, opts.script_error
      end
      if opts.reply ~= nil then
        return opts.reply
      end
      return server.run_script(source, { key }, { ... })
    end
    function client.evalsha(_, sha, _, key, ...)
      log.evalsha = log.evalsha + 1
      log.sha = sha
      if not server.script_loaded then
        return false, "NOSCRIPT No matching script. Please use EVAL."
      end
      return run(server.script_source, key, ...)
    end
    function client.eval(_, source, _, key, ...)
      log.eval = log.eval + 1
      server.script_loaded = true
      server.script_source = source
      return run(source, key, ...)
    end
    function client.ping()
      if opts.ping_error then
        return nil, opts.ping_error
      end
      return "PONG"
    end
    function client.set_keepalive()
      if opts.keepalive_error then
        return nil, opts.keepalive_error
      end
      log.keepalives = log.keepalives + 1
      return 1
    end
    function client.close()
      log.closes = log.closes + 1
      return 1
    end
    return client
  end

  return new, log
end

return M
