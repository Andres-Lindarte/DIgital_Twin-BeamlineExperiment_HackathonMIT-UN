--[[
cylinder_nonlinear_2dp.lua

This is an example of solving a system with non-linear dielectrics.
This requires an iterative application of Refine to achieve a
self-consistent solution, as described in the README and Supplemental Help.

D.Manura, 2012-01-05.
(c) 2011-2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

simion.workbench_program()

-- Number of Poisson iterations.
-- Increase if neccessary for convergence.
adjustable niterations = 15

-- Refine convergence objective (V). [*3]
adjustable convergence = 1E-5

-- Set to 1 (rather than 0) to continue iterating previous Fly'm.
adjustable resume = 0

-- References to PA instances and PA's.
local dipainst  = simion.wb.instances[1] -- dielectric constants in original (zero field)
local di2painst = simion.wb.instances[2] -- dielectric constants taking local field into account
local painst    = simion.wb.instances[3] -- electric potential
local dipa      = dipainst.pa
local di2pa     = di2painst.pa
local pa        = painst.pa

-- Defines non-linear dielectric properties as a function of
-- the local magnitude of the electric field, E (V/m), and the
-- zero-field dielectric constant (k0).
local lambda1 = 0   -- V/m
local lambda2 = 8.0E-17   -- V/m
local function nonlinear(E, k0)
  local lambda = (k0 == 6 and lambda2 or lambda1)
  return math.max(k0*(1 - lambda*E^2), 1)
end

-- Gets magnitude of field (V/mm) at point (x,y,z)
-- in PA volume units (gu).
-- Optionally given adjustable electrode voltages in table `t` (may be nil).
local function field(painst, xg,yg,zg, t)
  local pa = painst.pa
  local scale = painst.scale
  local ex,ey,ez = pa:field_vc(xg,yg,zg, t)  -- V/gu
  ex,ey,ez = ex/pa.dx_mm,ey/pa.dz_mm,ez/pa.dz_mm  -- V/mm
  local E = math.sqrt(ex^2 + ey^2 + ez^2)/scale -- V/mm
  return E
end

-- Update dielectric constants based on local electric field in previous Refine.
local function update_dielectrics()
  for xg,yg,zg in di2pa:points() do
    local xc,yc,zc = xg+0.5,yg+0.5,zg+0.5 -- center of grid cell [*1]
    local E = field(painst, xc,yc,zc)*1E+3  -- V/m
    local k0 = dipa:potential(xg,yg,zg)  -- zero field relative dielectric constant
    local k = nonlinear(E, k0)           -- non-zero field relative dielectric constant
    di2pa:potential(xg,yg,zg, k)
    if xg == 100 and yg == 100 then print('k(center)=', k) end -- helps to judge convergence
  end
end

-- called by SIMION on clicking Fly'm.
function segment.flym()
  -- Initialize current dielectric array (di2pa) with original
  -- zero field dielectric array (dipa) values.
  if resume == 0 then
    for xg,yg,zg in di2pa:points() do
      local k = dipa:potential(xg,yg,zg)
      di2pa:potential(xg,yg,zg, k)
      if xg == 100 and yg == 100 then print('k(center)=', k) end -- helps to judge convergence
    end
    simion.redraw_screen()
  end
  
  -- Iteratively re-solve Poisson equation, hopefully achieving a convergence
  -- to a self-consistent solution.
  for i=1,niterations do
    -- Solve PA using dielectric values in previous iteration.
    pa:refine{permittivity=di2pa, convergence=convergence, skipped_point=(resume==0 and i<=5)} --[*2][*3]

    update_dielectrics()
  
    -- Update display.
    simion.redraw_screen()
  end
end

--[[
 Footnotes:

 [*1] It's important to evaluate dielectric constants at centers of grid cells
      for highest accuracy.  Moreover, the iterative solution will slowly
      diverge otherwise.
 [*2] Later iterations (which don't change much) disable skipped
      refining to hopefully speed up the refines.
	  
 [*3] No need to set the convergence objective too low.  We want to call
      update_dielectrics() frequently enough.  Note also that the convergence
      objective is relative to the very high voltages in this system.
--]]