-- test.lua - SIMION workbench user program illustrating use of
-- SDS model with P,T,v defined via via adjustable variables or
-- array text files.

simion.workbench_program()

-- Load SDS program.
local SDS = simion.import("collision_sds.lua")

function SDS.init()
  -- Plot gas flow.
  local CON = simion.import '../contour/contourlib81.lua'  -- [3][4]
  CON.plot{func=SDS.velocity,  npoints=20, z=0, mark=true} --[2]
end


--[[
 Footnotes
 [2] Other examples of possible gas flow plots (multiple possible):
     -- Plots velocity vector field over entire volume.
     CON.plot{func=SDS.velocity, npoints=20, mark=true}
     -- Plots z=0 cross section of velocity vector field.
     CON.plot{func=SDS.velocity, npoints=20, z=0, mark=true}
     -- Plots pressure scalar field over entire volume.
     CON.plot{func=SDS.pressure, npoints=20, mark=true}
     -- Plots temperature scalar field over entire volume.
     CON.plot{func=SDS.temperature, npoints=20, mark=true}
 [3] Contour plotting with contourlib81.lua requires SIMION 8.1.
 [4] Best to do contour plotting in SDS.init rather than top-level
     in case flow is defined via adjustable variables (whose adjustments
     from the Variables tab are not active at the top-level).
--]]