--[[
mu_torus_3dp.lua
Solves magnetic field due to permeable torus.

D.Manura, 2012-05.
(c) 2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1/8.2)
--]]

simion.workbench_program()
simion.early_access(8.2) -- http://simion.com/info/early_access.html

local muinst = simion.wb.instances[1]  -- permeability, mu
local oinst  = simion.wb.instances[2]  -- magnetic scalar potential, Omega

-- B-field from magnetic scalar potential.
local bfields = simion.import'maglib.lua'.make_bfield_scalar(oinst, muinst.pa, 'x')

function segment.flym()
  -- Solve.
  oinst.pa:refine{permeability=muinst.pa, convergence=1e-5}

  -- Plot.
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot{func=bfields, npoints=30, z=0, mark=true}
  
  run() -- continue run.
end
