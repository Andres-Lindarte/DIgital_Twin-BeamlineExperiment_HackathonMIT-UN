--[[
 Optimization routine based on binary search.

 2012-08-14,2009-07, D.Manura
 (c) 2009-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

local M = {}

function M.optimize(min_voltage, max_voltage, max_tries, ygoal, callback)
  local upper_volts  -- last upper bound voltage
  local lower_volts  -- last lower bound voltage
  local upper_y = 0  -- last upper y hit
  local lower_y = 0  -- last lower y hit
  local y            -- last y hit
  local test_voltage
  
  upper_volts = min_voltage
  lower_volts = max_voltage

  -- Perform runs.
  local is_goal_reached
  for i=1, max_tries do
    -- Perform run.
    if i == 1 then  -- first run
      test_voltage = min_voltage
      y = assert((callback(test_voltage)))
      upper_y = y
    elseif i == 2 then  -- second run
      test_voltage = max_voltage
      y = assert((callback(test_voltage)))
      lower_y = y
      if upper_y <= lower_y then -- swap
        upper_volts, lower_volts = lower_volts, upper_volts
      end
    else  -- subsequent runs (mid-point voltage)
      test_voltage = (upper_volts + lower_volts) / 2
      y = assert((callback(test_voltage)))
      if y < 0 then   -- reverse tuning
        lower_volts = test_voltage
      else                    -- direct tuning
        upper_volts = test_voltage
      end
    end

    -- Display results.
    print("n = "..i..", y = "..y..", volts = "..test_voltage)

    -- Is goal reached?
    if abs(y) <= ygoal then
      print("Attained tuning goal of", ygoal)
      is_goal_reached = true
      break
    end
  end
  if not is_goal_reached then
    print("Aborted: Hit loop limit")
    error("Aborted: Hit loop limit")
  end

  return
end

return M
