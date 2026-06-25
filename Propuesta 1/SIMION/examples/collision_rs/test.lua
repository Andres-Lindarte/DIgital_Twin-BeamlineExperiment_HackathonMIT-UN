-- test.lua - SIMION workbench user program illustrating use of
-- the chemical reaction model extension to SDS (SIMON SDS / RS)

simion.workbench_program()

-- Load SDS / RS user program: 
local SDS = simion.import("RS_collision_sds.lua")

function SDS.init()
  -- Plot gas flow.
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot{func=SDS.velocity,  npoints=20, z=0, mark=true}
end

function segment.load()
  -- On IOB load, default to Grouped flying with T.Qual=0.
  sim_grouped = 1
  sim_trajectory_quality = 0
end
