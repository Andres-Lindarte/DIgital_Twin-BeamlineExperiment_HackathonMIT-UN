--[[
 tune.lua - lens tuning example.

 This focuses on ion #6.

 The electrode tuning resembles a binary search.  It searches for an
 electrode voltage that causes ions to hit within a certain radius.
 The search terminates when the goal is reached or the maximum permitted
 number of tries is exceeded.

 D.Manura, 2012-08-14.
 (c) 2009-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()

adjustable min_voltage = 0           -- tuning voltage lower bound
adjustable max_voltage = 1000        -- tuning voltage upper bound
adjustable abs_goal_for_y = 0.001    -- goal for abs(y) bounds
adjustable max_tries = 20            -- max number of iterations

local BOL = simion.import 'binaryoptlib.lua'

local test_voltage         -- electrode voltage (current run)
local last_y               -- current value of metric being tuned
local first


function segment.flym()
  sim_trajectory_image_control = 1 -- don't keep trajectories

  BOL.optimize(min_voltage, max_voltage, max_tries, abs_goal_for_y, function(test_voltage_)
    test_voltage = test_voltage_
    first = true
    last_y = nil -- reset for next run
    run()
    return last_y
  end)

  -- Do one more run, keeping trajectories.
  sim_trajectory_image_control = 0 -- keep trajectories
  run()
  
  sim_retain_changed_potentials = 1 -- keep electrode voltages
end


-- called on start of each run to set electrode voltages, updating all points.
function segment.init_p_values()
  adj_elect02 = test_voltage
end


-- called on every time-step for each particle in PA instance.
function segment.other_actions()
  -- update PE surface is update flagged
  if first then first = false; sim_update_pe_surface = 1 end
end


-- called on each particle termination inside a PA instance.
function segment.terminate()                  
  -- Tune at end of each fly.
  if ion_number == 6 then     -- tune only on ion 6
    last_y = ion_py_gu
  end
end
