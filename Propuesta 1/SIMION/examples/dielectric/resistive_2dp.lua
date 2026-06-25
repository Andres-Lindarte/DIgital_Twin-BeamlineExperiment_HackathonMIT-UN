--[[
resistive_2dp.lua

This example demonstrates using the Poisson (Refine) solver for solving
current density through space given varying conductivity through space.

D.Manura, 2012-01-05.
(c) 2011-2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

simion.workbench_program()

local copainst = simion.wb.instances[1]  -- conductivity (relative values)
local painst   = simion.wb.instances[2]  -- electric potential

-- Refine convergence objective (V).
adjustable convergence = 1E-5

-- Gets magnitude of field (normally V/mm) at point (x,y,z)
-- in workbench units (mm).
-- Optionally given adjustable electrode voltages in table `t` (may be nil).
-- Returns 0,0,0 outside.
local function field(painst, x,y,z, t)
  local pa = painst.pa
  local scale = painst.scale
  local xg,yg,zg = painst:wb_to_pa_coords(x,y,z)
  if not pa:inside_vc(xg,yg,zg) then return 0,0,0 end
  local ex,ey,ez = pa:field_vc(xg,yg,zg, t)  -- V/gu
  ex,ey,ez = ex/(pa.dx_mm*scale),ey/(pa.dz_mm*scale),ez/(pa.dz_mm*scale)  -- V/mm
  ex,ey,ez = painst:pa_to_wb_orient(ex,ey,ez)
  return ex,ey,ez
end

-- Gets scalar value (normally potential) at point (x,y,z)
-- in workbench units (mm).
-- Optionally given adjustable electrode voltages in table `t` (may be nil).
-- Returns 0 outside.
local function scalar(painst, x,y,z, t)
  local pa = painst.pa
  local xg,yg,zg = painst:wb_to_pa_coords(x,y,z)
  if not pa:inside_vc(xg,yg,zg) then return 0 end
  local v = pa:potential_vc(xg,yg,zg, t)
  return v
end

-- Gets current density (A/mm^2) at point (x,y,z) in workbench units (mm).
-- Returns 0,0,0 outside.
local function current_density(x,y,z)
  local ex,ey,ez = field(painst, x,y,z)
  local sigma = scalar(copainst, x,y,z)
  local jx,jy,jz = ex*sigma, ey*sigma, ez*sigma
  return jx,jy,jz
end

-- Called by SIMION on Fly'm.
function segment.flym()
  -- Refine electric potential array, giving conductivity (copainst.pa).
  -- Note: the conductivity is passed to pa:refine in the same manner
  -- as a dielectric.
  painst.pa:refine {permittivity=copainst.pa, convergence=convergence}

  -- Redraw graphics.
  simion.redraw_screen()
  
  -- Optionally, plot current density vector field.
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot {current_density, mark=true}
  
  -- Print current density across center line (as a test).
  for y=0,100,5 do
    local jx,jy,jz = current_density(50,y,0)
    print(y, jy)
  end
end
