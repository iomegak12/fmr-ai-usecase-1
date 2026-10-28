-- luacheck settings for the gateway Lua modules and their busted specs.
std = "ngx_lua"
max_line_length = 100

files["spec/"] = {
  std = "+busted",
  -- Specs install a fake ngx for each test.
  globals = { "ngx" },
}
