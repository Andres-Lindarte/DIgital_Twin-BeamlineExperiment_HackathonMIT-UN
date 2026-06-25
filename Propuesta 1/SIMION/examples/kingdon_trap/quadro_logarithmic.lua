--[[
 quadro_logarithmic.lua - workbench user program to assist simulation.
 D.Manura, 2012-03.
--]]

simion.workbench_program()

-- Maximum time in microseconds to fly particles (prevents flying forever).
adjustable max_time = 30

-- This is executed on IOB load...
function segment.load()
  -- Generate analytic PA surface with PA API code.
  simion.import 'quadro_logarithmic_build.lua'
  
  -- Set initial particle flying parameters.
  sim_grouped = 1
  sim_trajectory_quality = 0
end

function segment.other_actions()
  -- Limit flight time.
  if ion_time_of_flight > max_time then
    ion_splat = 1
  end
end
