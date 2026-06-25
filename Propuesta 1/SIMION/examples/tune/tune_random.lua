--[[
 tune_random.lua - lens tuning example with random voltages.

 The electrode tuning by selecting random voltages within a range.
 
 This focuses on ion #6 hit position.

 D.Manura, 2012-08-14,2009-07
 (c) 2009-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()

adjustable V2_voltage_min = 0           -- tuning voltage lower bound
adjustable V3_voltage_min = 0           -- tuning voltage lower bound
adjustable V2_voltage_max = 1000        -- tuning voltage upper bound
adjustable V3_voltage_max = 1000        -- tuning voltage upper bound
adjustable max_tries = 100

local V2_voltage              -- electrode voltage V2 (current run)
local V3_voltage              -- electrode voltage V3 (current run)
local update_pe              -- true iff PE display refresh requested
local metric                 -- current value of metric being tuned
local best = {metric = math.huge}

local function next_parameters(metric)
  if metric and metric < best.metric then
    best = {metric=metric, V2=V2_voltage, V3=V3_voltage}
    print('best metric so far', metric, 'V2=', V2_voltage, 'V3=', V3_voltage)
  end
  V2_voltage = V2_voltage_min + (V2_voltage_max-V2_voltage_min)*rand()
  V3_voltage = V3_voltage_min + (V3_voltage_max-V3_voltage_min)*rand()
end

function segment.flym()
  sim_trajectory_image_control = 1 -- don't keep trajectories

  repeat
    next_parameters(metric)
    run()
  until ion_run > max_tries
  print('max_tries reached', max_tries)
  
  -- Rerun best result, keeping trajectories.
  print('Rerunning V2='..best.V2..',V3='..best.V3)
  V2_voltage = best.V2
  V3_voltage = best.V3
  sim_trajectory_image_control = 0 -- keep trajectories
  run()
  
  sim_retain_changed_potentials = 1 -- keep tuned electrode voltages
end

-- called on start of each run.
function segment.initialize_run()
  metric = nil  -- reset for next run
end


-- called on start of each run to set electrode voltages, updating all points.
function segment.init_p_values()
  adj_elect02 = V2_voltage
  adj_elect03 = V3_voltage
end


-- called on every time-step for each particle in PA instance.
function segment.other_actions()
  -- Update PE surface on first time-step.
  if update_pe then update_pe = false; sim_update_pe_surface = 1 end

  -- Immediately kill ions that reverse velocity
  -- (faster run-times and avoids hangs if particles travel
  -- in infinite loop).
  if ion_vx_mm < 0 then
    ion_splat = -4
  end
end



-- called on each particle termination inside a PA instance.
function segment.terminate()                  
  -- Tune at end of each fly.
  if ion_number == 6 then     -- tune only on ion 6
    metric = ion_px_mm > 95 and abs(ion_py_gu)
  end
end


--[[
 Footnotes:
 [1] The flym/initialize_run/terminate_run segments are new in SIMION 8.1.0.40.
     See "Workbench Program Extensions in SIMION 8.1" in the supplemental
     documentation (Help menu).
--]]
