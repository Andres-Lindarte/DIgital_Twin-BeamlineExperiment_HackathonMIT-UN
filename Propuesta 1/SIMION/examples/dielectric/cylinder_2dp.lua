--[[
cylinder_2dp.lua
Solves electric field due to dielectric cylinder.

D.Manura, 2012-01-05.
(c) 2011-2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

simion.workbench_program()

local dipa = simion.wb.instances[1].pa  -- dielectric constants
local pa   = simion.wb.instances[2].pa  -- electric potential
local painst=simion.wb.instances[2]

-- Adjustable dielectric constants inside and outside of cylinder.
adjustable kinside = 10
adjustable koutside = 1

-- Refine convergence objective (V).
adjustable convergence = 1E-5

-- Called by SIMION on Fly'm.
function segment.flym()
  -- Optionally replace dielectric constants from adjustable variables.
  dipa:load()  -- reload original
  for xg,yg,zg in dipa:points() do
    local p = dipa:potential(xg,yg,zg)
    p = (p == 1) and koutside or kinside
    dipa:potential(xg,yg,zg, p)
  end
 
  -- Refine.
  pa:refine{convergence=convergence, permittivity=dipa}
  
  -- Update display.
  simion.redraw_screen()
  
  -- Analyze results.
  local E_0 = 1   -- V/mm
  local function norm(x,y,z) return math.sqrt(x^2+y^2+z^2) end
  print('E(center)_theo=',   E_0*2/(kinside/koutside + 1))
  print('E(center)_actual=', norm(painst:field_wc(50,50,0)))
end
