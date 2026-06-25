--[[
 spotential_from_bfield.lua
 Converts vector B-field to magnetic scalar potential PA
 (and back again).
 Note: assumes negligible current density in PA region.
 
 D.Manura, 2012-03,2012-02
 (c) 2011-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()
simion.early_access(8.2) -- http://simion.com/info/early_access.html

-- System parameters.
local R = 30        -- cylinder radius, mm
local current = 0   -- cylinder current, A
local B0 = 100      -- transverse B-field, gauss
adjustable mu_outside = 5  -- relative permeability outside cylinder
adjustable mu_inside = 1   -- relative permeability inside cylinder

local MU0 = require 'simionx.Constants'.MAGNETIC_CONSTANT_N_A

-- distribution of relative permeability through space.
local function mutheo(x,y,z)
  local r = math.sqrt(x^2+y^2)
  return r <= R and mu_inside or mu_outside
end

-- theoretical B-field (B=(mu_r*mu_0)*H).
local function btheo(x,y,z)
  local r = math.sqrt(x^2+y^2)
  if r == 0 then return 0,0,0 end--FIX
  local mur = mu_inside/mu_outside
  local C = -mur*MU0*current/(4*math.pi)
  local E = (mur - 1)/(mur + 1)
  local F = MU0*current/(2*math.pi)
  local GAUSS_PER_TESLA = 10000
  local MM_PER_M = 1000
  local CONV = GAUSS_PER_TESLA * MM_PER_M
  if r < R then
    return 2*C*y*R^-2*CONV + (1+E)*B0, -2*C*x*R^-2*CONV, 0
  else
    return -2*E*y^2*R^2*r^-4*B0 + (1 + E*R^2*r^-2)*B0 - F*r^-2*y*CONV,
            2*E*x*y*R^2*r^-4*B0 + F*x*r^-2*CONV,
            0
  end
end

-- theoretical H-field (actually mu_0*H in gauss units).
local function htheo(x,y,z)
  local mu = mutheo(x,y,z)
  local bx,by,bz = btheo(x,y,z)
  bx,by,bz = bx/mu, by/mu, bz/mu
  return bx,by,bz
end


function segment.flym()
  simion.redraw_screen()

  -- Obtain PA instance (where magnetic scalar potential shall be stored).
  local Oinst = simion.wb.instances[1]
  
  -- Express B-field in terms of magnetic scalar potential PA (not yet computed).
  local bfields = simion.import'maglib.lua'.make_bfield_scalar(Oinst, mutheo, 'x')
  
  -- Convert H-field to scalar magnetic potential.
  local N = 10 -- integration steps per grid unit (higher for more accuracy).
  simion.experimental.spotential_from_vfield(Oinst, htheo, N)

  -- Plot original and converted B-fields for comparison.
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot{npoints=20, npointsz=2, mark=true, z=0,
    {func=bfields, color=1},
    {func=btheo, color=3}
  }
end
