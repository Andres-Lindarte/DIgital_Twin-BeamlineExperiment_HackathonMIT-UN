-- simionx.Type
-- This module is documented in the SIMION supplemental documentation.
-- version: 20080821
-- (c) 2007 Scientific Instrument Services, Inc. (SIMION 8.0 License)

local M = {typename = "type"}
M.typefunc = function(o) return getmetatable(o) == M end
M.__index = M
setmetatable(M, M)

function M.__add(a, b) return M.or_type(a, b) end

function M.__call(self, ...) return self:__init(...) end

function M.is(self, o) return self.typefunc(o) end

function M.check(self, o, level)
  local is, msg = self:is(o)
  if not is then
    error(msg or self.typename, (level or 1) + 1)
  end
end

function M.__init(class, typefunc, typename)
  if type(typefunc) == "table" then
    local table = typefunc
    typefunc = function(o)
      return M.is_param_table(table, o)
    end
  end
  local self = setmetatable({typefunc = typefunc, typename = typename}, M)
  return self  
end

function M.is_param_table(tformat, t)
  if type(t) ~= 'table' then
    return false, 'table expected (got ' .. tostring(t) .. ')'
  end
  for name,check in pairs(tformat) do
    if not check:is(t[name]) then
      return false, "field " .. name .. " not a " .. check.typename
    end
  end
  for name in pairs(t) do
    if not tformat[name] then
      return false, "field " .. name .. " not recognized"
    end
  end
  return true
end

-- Creates new type that is logical OR of given types.
function M.or_type(...)
  local types = {...}
  local func;
    if #types > 2 then
      func = function(o)
        for _,t in ipairs(types) do
          if t:is(o) then return true end
        end
        return false
      end
    elseif #types == 2 then -- small optimization
      local t1, t2 = types[1], types[2]
      func = function(o) return t1:is(o) or t2:is(o) end
    elseif #types == 1 then -- small optimization
      return types[1]
    else -- #types == 0  -- small optimization
      func = function() return false end
    end
  local name = ""
  for _,func1 in ipairs(types) do
    if name ~= "" then name = name .. " or " end
    name = name .. func1.typename
  end
  return M(func, name)
end

-- Various common types are instantiated below for convenience.

function M.is_nil(o) return o == nil end
M['nil'] = M(M.is_nil, 'nil')
function M.is_boolean(o) return type(o) == "boolean" end
M.boolean = M(M.is_boolean, "boolean")
function M.is_number(o) return type(o) == "number" end
M.number = M(M.is_number, "number")
function M.is_string(o) return type(o) == "string" end
M.string = M(M.is_string, "string")
function M.is_function(o) return type(o) == "function" end
M['function'] = M(M.is_function, "function")
function M.is_userdata(o) return type(o) == "userdata" end
M.userdata = M(M.is_userdata, "userdata")
function M.is_thread(o) return type(o) == "thread" end
M.thread = M(M.is_thread, "thread")
function M.is_table(o) return type(o) == "table" end
M.table = M(M.is_table, "table")

function M.is_callable(o)
  return type(o) == "function" or getmetatable(o) ~= nil end
M.callable = M(M.is_callable, "callable object (e.g. function)")

local floor = math.floor

function M.is_integer(o) return type(o) == "number" and floor(o) == o end
M.integer = M(M.is_integer, "integer")
function M.is_positive_integer(o) return M.is_integer(o) and o > 0 end
M.positive_integer = M(M.is_positive_integer, "positive integer")
function M.is_negative_integer(o) return M.is_integer(o) and o < 0 end
M.negative_integer = M(M.is_negative_integer, "negative integer")
function M.is_nonnegative_integer(o) return M.is_integer(o) and o >= 0 end
M.nonnegative_integer = M(M.is_nonnegative_integer, "nonnegative integer")
function M.is_nonpositive_integer(o) return M.is_integer(o) and o <= 0 end
M.nonpositive_integer = M(M.is_nonpositive_integer, "nonpositive integer")
function M.is_positive_number(o) return M.is_number(o) and o > 0 end
M.positive_number = M(M.is_positive_number, "positive number")
function M.is_negative_number(o) return M.is_number(o) and o < 0 end
M.negative_number = M(M.is_negative_number, "negative number")
function M.is_nonnegative_number(o) return M.is_number(o) and o >= 0 end
M.nonnegative_number = M(M.is_nonnegative_number, "nonnegative number")
function M.is_nonpositive_number(o) return M.is_number(o) and o <= 0 end
M.nonpositive_number = M(M.is_nonpositive_number, "nonpositive number")

function M.is_simple_table(o)
  return type(o) == "table" and getmetatable(o) == nil
end
M.simple_table = M(M.is_simple_table, "simple table")

function M.is_array(o)
  local is = false
  if M.is_simple_table(o) then
    local n = 1
    while o[n] ~= nil do n = n + 1 end
    n = n - 1
    local size = 0
    for k in pairs(o) do size = size + 1 end
    is = (n == size)
  end
  return is
end
M.array = M(M.is_array, "array table")

function M.is_number_array(o)
  if M.is_array(o) then
    local n = 1
    while true do
      local v = o[n]; if v == nil then return true end
      if not M.is_number(v) then
        return false
      end
      n = n + 1
    end
  end
  return false
end
M.number_array = M(M.is_number_array, "array table of numbers")

local is_vector_t = {}; setmetatable(is_vector_t, {__mode = "k"})
function M.is_vector(o) return is_vector_t[o] end
M.vector = M(M.is_vector, "vector")
M.vector.__init = function(class, x,y,z)
  local v = {x,y,z}
  is_vector_t[v] = true
  return v
end

function M.is_number_vector(o)
  return M.is_vector(o) and M.is_number(o[1]) and
         M.is_number(o[2]) and M.is_number(o[3])
end
M.number_vector = M(M.is_number_vector, "vector of numbers")

function M.is_nonzero_number_vector(o)
  return M.is_number_vector(o) and not(o[1] == 0 and o[2] == 0 and o[3] == 0)
end
M.nonzero_number_vector = M(
  M.is_nonzero_number_vector, "non-zero vector of numbers")

return M
