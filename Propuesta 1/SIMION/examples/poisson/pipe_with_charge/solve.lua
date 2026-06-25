--[[
 Computes potentials due to cylinder of charge inside conductive pipe
 using SIMION's Poisson solver.
 See README.html for details.

 D.Manura, 2011-12-12
 (c) 2011 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

-- Some utilities that simplify PA access.
local PAL = simion.import '../palib.lua'

-- Some general physical constants.
local C = require "simionx.Constants"
local EPSILON0 = C.ELECTRIC_CONSTANT_F_M  -- (F/m)
local K = 1/(4*math.pi*EPSILON0)

-- Radius of outer cylinder (mm)
local R2 = 1000

-- Radius of inner (charge) cylinder (mm)
local R1 = 100

-- x,y offset of charge (mm)
local x0 = 0
local y0 = R2/2

-- Charge density, C/mm^3
local rho = 1E-16

-- Refine convergence level.
-- NOTE! reduce convergence level for better accuracy
local convergence = 1e-5

-- PA grid coordinate definitions.
local coords = {
  symmetry = '2dplanar[x]',        -- PA symmetry
  xmin = 0, ymin = -R2, zmin = 0,   -- Min/max corners of boundary box in system units (mm)
  xmax = R2, ymax =  R2, zmax = 0,
  xwo = 0, ywo = 1000, zwo = 0,       -- x,y,z offset of system origin (0,0) in PA volume units (gu)
  dx_mm = 1, dy_mm = 1, dz_mm = 1, -- PA grid cell sizes in each dimension (mm).
}

--[[
 Define the system in SIMION PA's and Poisson solve with Refine.
--]]
local function solve()
  simion.pas:close()

  -- Define potential and space-charge arrays.
  local pa = PAL.create_pa(coords)
  pa.filename = 'pipe.pa'
  local chargepa = PAL.create_charge_pa(pa) -- build compatible charge PA

  -- Define potential and space-charge boundary conditions.
  -- (Alternately, e.g., do this with a GEM file.)
  PAL.fill_array_from_function(pa, coords, function(x,y,z)
    if x^2+y^2 >= R2^2 then
      return 0, true
    end
  end)
  PAL.fill_array_from_function(chargepa, coords, function(x,y,z)
    if (x-x0)^2+(y-y0)^2 <= R1^2 then
      return rho
    end
  end)
  local sum = 0

  -- Just as a check, display the total C/mm in the charge array.
  for x,y,z in chargepa:points() do
    sum = sum + chargepa:potential(x,y,z)
  end
  print('Total charge=', sum*chargepa.dx_mm*chargepa.dy_mm)
  
  -- Poisson solve
  pa:refine{charge=chargepa, convergence=convergence}
  pa.refinable = false  -- prevent accidental refine without space-charge
  pa:save()
  
  return pa
end


--[[
 The is the theoretical (expected) analytic equation for the
 potential as a function of position.  This is not used in the
 Poisson solve but is only provided for comparison.
 The formulas are derived in README.html.
--]]
local function theoretical_potential(x,y,z)
  if x^2 + y^2 >= R2^2 then return 0 end
  local lambda = rho * math.pi*R1^2 * 1E3  -- C/m
  local zz0m = math.sqrt((x-x0)^2 + (y-y0)^2)  -- distance to charge center (mm)
  local phid = (zz0m <= R1) and
    (1 - (zz0m/R1)^2 - 2*math.log(R1*1E-3))*lambda*K or
    -2*math.log(zz0m*1E-3)*lambda*K 
  local z0m = math.sqrt(x0^2 + y0^2)
  local phii
  if z0m == 0 then
    phii = 2*math.log(R2*1E-3)*lambda*K
  else
    local xi = x0 * (R2^2 / (x0^2 + y0^2))
    local yi = y0 * (R2^2 / (x0^2 + y0^2))
    local zzim = math.sqrt((x-xi)^2+(y-yi)^2)
    phii = (2*math.log(zzim*z0m/R2*1E-3))*lambda*K  
  end
  return phid+phii
end

local function compare(pa, theoretical_potential)
  -- Compare to theoretical potential.
  print('y', 'phi', 'phi_t', 'phi-phi_t')
  local x = 0
  local z = 0
  for y=0, 1000, 25 do  -- mm
    local phi = pa:potential_vc(PAL.system_to_pa_units(coords, x,y,z))
    local phi_t = theoretical_potential(x,y,z)
    print(y, phi, phi_t, phi-phi_t)
  end
end

-- Solve field in SIMION PA's.
local pa = solve()

-- Compare to theoretical.
compare(pa, theoretical_potential)

-- Create additional PA's to assist in evaluating fields:
-- PA with theoretical fields and PA with difference between calculated and theoretical
local theopa = PAL.build_pa_from_function(coords, theoretical_potential)
theopa.filename = 'pipe-theo.pa'
theopa.refinable = false
local diffpa = PAL.diff_pas(pa, theopa)


print 'DONE'
