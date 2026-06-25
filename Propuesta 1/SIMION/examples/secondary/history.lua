---------------------------------------------------
-- history.lua - Lua history module.
--
-- This module is designed for recording arbitrary data along a
-- particle trajectory path as the particle flies and interpolating
-- that data at any point on the path. The module can be configured
-- to discard data beyond a specified distance back (saves memory).
--
-- This module was originally intended for use with the
-- secondary emission implementation (secondarylib.lua)
-- for the purpose of recalling the electric field vector
-- a given distance back along the ion trajectory from the
-- surface splat point.
--
-- David Manura, 2007-01
-- (c) 2007 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)
---------------------------------------------------

module("history", package.seeall)

-- Compute Cartesian distance between two 3D vectors
-- (utility function)
local function getdistance(v1, v2)
  return math.sqrt(
      (v1[1] - v2[1])^2 + (v1[2] - v2[2])^2 + (v1[3] - v2[3])^2)
end

-- The History data type
HistoryClass = {}
HistoryClass.__index = HistoryClass

-- Constructor for History object.
-- params:
--   max_distance - record at least this much distance.
--                  if nil, then infinite.
function History(max_distance)
  local self = setmetatable({max_distance = max_distance}, HistoryClass)
  return self
end

-- Resets max_distance attribute.
function HistoryClass:set_max_distance(max_distance)
  self.max_distance = max_distance
end

-- Insert new data point into the history.
function HistoryClass:insert(o)
  -- Store new element.
  table.insert(self, o)

  -- Remove old elements beyond max_distance.  (Actually, this approach
  -- may store some extra additional elements, but that is normally ok
  -- assuming particles don't travel continuously in circles.)
  -- The algorithm is: while the Cartesian distance between the first
  -- and last elements is at least max distance after removing one
  -- element, remove that element.
  if self.max_distance then
    while #self > 2 and getdistance(self[2], self[#self])
                        >= self.max_distance
    do
      table.remove(self, 1)
    end
  end
end

-- Interpolate data at given distance back in history.
-- distance is a non-negative path length starting at the last
-- data point (distance of 0).
-- Raises error if distance is outside of history.
function HistoryClass:value_at_distance(distance)
  assert(distance >= 0)
  local n = #self  -- index of last point
  local result
  if distance == 0 then
    assert(n >= 1)
    result = self[n]
  else
    -- Find interval (curr_dist, next_dist] containing distance.
    local curr_dist = 0
    local next_dist = 0
    repeat
      -- Compute next interval.
      assert(n >= 2, distance .. " " .. next_dist)
      curr_dist, next_dist =
          next_dist, next_dist + getdistance(self[n-1], self[n])
      n = n - 1
      -- Invariant: curr_dist is path length from #self down to n+1.
      --            next_dist is path length from #self down to n.
    until next_dist + 1e-15 >= distance  -- interval found

    -- Interpolate data at point in this interval.
    local w1 = (next_dist - distance) / (next_dist - curr_dist)
    local w2 = (distance - curr_dist) / (next_dist - curr_dist)
    result = {}
    for m = 1,#self[n] do
      if type(self[n][m]) == "number" then  -- interpolatable data
        result[m] = w1 * self[n+1][m] + w2 * self[n][m]
      else -- non-interpolatable data (just return end-point)
        result[n] = self[n]
      end
    end
  end

  return result
end
