--[[
float_cylinder_2d.lua
Solves electric field due to "floating" conductive cylinder
(i.e. isolated from ground but with a possible non-zero charge).

The floating conductor is treated as a dielectric with near infinite
permittivity.  Optionally a non-zero charged is embedded inside it.

D.Manura, 2012-01-05.
(c) 2011-2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

simion.workbench_program()

-- Amount of charge to place on the floating conductor (C).
adjustable Q = 5E-13

-- Refine convergence objective (V).
adjustable convergence = 1E-5

local dipa  = simion.wb.instances[1].pa  -- dielectric constants
local pa    = simion.wb.instances[2].pa  -- electric potential
local painst= simion.wb.instances[2]

-- Called by SIMION on Fly'm.
function segment.flym()
  -- Optionally, define a charge distribution inside the cylinder.
  -- It's not really important what the charge distribution looks like.
  -- Near infinite permittivity inside the cylinder will force zero
  -- fields inside the cylinder regardless.
  -- The first line below creates a charge density PA compatible with `pa`.
  -- Then some charge is in the center region.
  local chpa = simion.import'../poisson/palib.lua'.cache_pa('float_charge', pa, -1)
  local area_mm2 = (20*chpa.dx_mm)^2 -- mm^2
  for zg=0,0 do
  for yg=90,110-1 do
  for xg=90,110-1 do
    chpa:potential(xg,yg,zg, Q / area_mm2)
  end end end
  -- Even a single point works but is less accurate and longer to converge:
  --  chpa:potential(100,100,0, Q/chpa.dx_mm^2)
  
  -- Refine with dielectric and charge density:
  pa:refine{permittivity=dipa, charge=chpa, convergence=convergence}
   
  -- Update display.
  simion.redraw_screen()
  
  -- As a test, perform a Gauss' law integration over some
  -- volume containing the cylinder in order to confirm
  -- that the charge is correct.
  local function field(x,y,z) return painst:field_wc(x,y,z) end -- mm
  local FAN = require 'simionx.FieldAnalysis'
  FAN.charge_from_gauss_law_display {
    field = field,
    shape = FAN.box(25,25,0, 75,75,1), -- mm
    min_iterations=200000, -- increase for higher accuracy
    rel_err=1E+99 -- disable
  } -- computes C per mm in z
  print('(expected '..Q..' C/mm)')
end
