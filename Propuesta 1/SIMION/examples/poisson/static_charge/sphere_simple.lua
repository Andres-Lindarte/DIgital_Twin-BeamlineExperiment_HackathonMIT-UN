--[[
 sphere_simple.lua.

 Simple test of the Poisson solver.
 This models a uniform sphere of space-charge of density `rho` (C/mm^3)
 and radius `R1` inside a larger conductive sphere of radius `R2`.
 The spheres are concentric.  The potentials inside `R2` are solved.
 
 D.Manura, 2011-12.
--]]


-- Remove all PA's from RAM.
simion.pas:close()

-- Convert GEM files to PA's,
-- both the electric field PA and the space-charge PA.
simion.command 'gem2pa sphere_simple.gem'
simion.command 'gem2pa sphere_simple-charge.gem'

-- Load PA's.
local pa       = simion.pas:open 'sphere_simple.pa'
local chargepa = simion.pas:open 'sphere_simple-charge.pa'

-- Refine electric field PA using space-charge PA.
pa:refine{charge=chargepa, convergence=1e-5}

-- Finally, let's evaluate the results...

local R1=5  -- mm
local R2=10 -- mm
local rho=1E-10 -- C/mm^3

-- As a check to ensure the problem was correctly defined to begin with,
-- total the charge in the space-charge PA.
local Q_actual = simion.import '../palib.lua'.total_charge(chargepa)
local Q_theo   = (4/3)*math.pi*R1^3*rho
print('Q(actual)=', Q_actual, 'Q(theo)=', Q_theo)

-- Compare computed potentials to theoretical potentials.
local EPSILON_0 = require 'simionx.constants'.ELECTRIC_CONSTANT_F_M
local function v_theo(r) -- theoretical potential, at r (in mm).
  local mm_per_m = 1E+3
  return mm_per_m*(rho/3/EPSILON_0)*((r < R1 and -r^2/2+(3/2)*R1^2 or R1^3/r) - R1^3/R2)
end
for r=0,10 do -- mm
  local xg, yg, zg = r*10, 0, 0  -- gu
  print('r=', r, 'V(actual)=', pa:potential_vc(xg,yg,zg), 'V(theo)=', v_theo(r), 'E(actual)=',pa:field_vc(xg,yg,zg))
end

print 'DONE'
