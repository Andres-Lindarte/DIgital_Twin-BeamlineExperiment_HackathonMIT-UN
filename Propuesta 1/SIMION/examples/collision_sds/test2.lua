-- test2.lua - SIMION workbench user program illustrating use of
-- SDS model with P,T,v defined via functions (e.g. containing
-- expressions defined analytically).

simion.workbench_program()

-- Load SDS program.
local SDS = simion.import("collision_sds.lua")

-- Warning: the P,T,v values used below are only examples for
-- demonstration.  They do not necessarily make sense from a
-- steady-state flow dynamics perspective.

function SDS.pressure(x,y,z) -- Torr
  local p
  if x > 20 then
    p = 100 + 660 * ((x-20)/80)
  else
    p = 100
  end
  --print(('DEBUG:x=%g,y=%g,z=%g,P=%g'):format(ion_px_mm,ion_py_mm,ion_pz_mm,p))
  return p
end
function SDS.temperature(x,y,z) -- K
  return 300
end
function SDS.velocity(x,y,z)  -- (m/s) vx,vy,vz in workbench coordinates
  local vx = math.max(20-math.abs(y), 0)/5 * math.max(40-math.abs(x-50), 0)/40
  local vy = 5*y/100 * (x > 50 and 1 or -1)
  local vz = 0
  return vx,vy,vz
end

function SDS.init()
  -- Plot gas flow.
  local CON = simion.import '../contour/contourlib81.lua'  -- [3][4]
  CON.plot{func=SDS.velocity,  npoints=20, z=0, mark=true} --[2]
  CON.plot{func=SDS.velocity,  npoints=20, y=0, mark=true}
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
