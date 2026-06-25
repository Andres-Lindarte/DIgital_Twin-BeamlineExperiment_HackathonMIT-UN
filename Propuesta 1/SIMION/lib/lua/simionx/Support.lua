-- simionx.Support
-- This module is documented in the SIMION supplemental documentation.
-- version: 20070816
-- (c) 2007 Scientific Instrument Services, Inc. (SIMION 8.0 License)

if not simion then simion = {} end

-- Helper function added to modules defined by simionmodule
-- to support importing module symbols into client namespace.
-- See documentation below on Sup.module().
local function import(public, ...)
  -- Extract arguments.
  local target, options = ...
  if type(target) ~= "table" then
    target, options = nil, target
  end
  target = target or getfenv(2)

  -- Export symbols.
  if options == ":all" then
    for k,v in pairs(public) do target[k] = v end
  end

  return public
end

local function module()
  local M = {}
  setmetatable(M, {__call = import})
  return M
end

local M = module()

M.module = module

-- undocumented
-- with statement
function M.with(public)
  local level = 2
  local old_env = getfenv(level)  -- Save.

  -- Create local environment.
  local env = {}
  setmetatable(env, {
    __index = function(self, k)
      local v = public[k]; if v == nil then v = old_env[k] end
      return v
    end
  })
  setfenv(level, env)

  return function(...)
    setfenv(2, old_env)  -- Restore.
    return ...
  end
end


function M.subst(s, t)
  -- note: handle {a=false} substitution
  s = s:gsub("%$%(([%w_]+)%)", function(name)
    local val = t[name]
    return val ~= nil and tostring(val)
  end)
  return s
end

return M
