--[[
 tune_simplex.lua - lens tuning example.

 This focuses the voltage of electrode #2 using
 position ion #6 using the simplex optimizer.

 D.Manura, 2012-08-14,2009-07
 (c) 2009-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()

adjustable V2_start = 500
adjustable V2_step = 100
adjustable optimizer_max_calls = 1e30
adjustable optimizer_min_radius = 1E-7
 
local SimplexOptimizer = require "simionx.SimplexOptimizer"
local metric           -- current value of parameter being optimized
local V2_voltage        -- electrode voltage in current run
local first_time_step

function segment.flym()
  sim_trajectory_image_control = 1 -- don't keep trajectories

  local opt = SimplexOptimizer {
    start = {V2_start},
    step = {V2_step},
    maxcalls=optimizer_max_calls,
    minradius=optimizer_min_radius
  }
  
  while opt:running() do
    V2_voltage = opt:values()  -- next voltage chosen by optimizer
    run()
    opt:result(metric)
    print("n = "..ion_run..", y = "..metric..", volts = "..V2_voltage) 
  end
  
  print("Attained tuning goal of ", optimizer_min_radius)
  
  -- Do one more run, keeping trajectories.
  sim_trajectory_image_control = 0 -- keep trajectories
  run()
  
  sim_retain_changed_potentials = 1  -- keep tuned electrode voltages
end

function segment.initialize_run()
  first_time_step = true
  metric = nil -- reset for next run
end

function segment.fast_adjust()
  adj_elect02 = V2_voltage
end

function segment.other_actions()
  -- Update PE surface.
  if first_time_step then first_time_step = false; sim_update_pe_surface = 1 end
end

function segment.terminate()                  
  if ion_number == 6 then   -- tune only on ion --6
    metric = abs(ion_py_gu)
  end
end

--[[
 Footnotes:
 [1] The flym/initialize_run/terminate_run segments are new in SIMION 8.1.0.40.
     See "Workbench Program Extensions in SIMION 8.1" in the supplemental
     documentation (Help menu).
--]]
