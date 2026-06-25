--[[
 mag_cylinder_2dc.lua
 Solves magnetic B-field of uniformly magnetized cylinder.
 See README.html for details.
 
 D.Manura, 2012-05
 (c) 2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1/8.2)
--]]

simion.workbench_program()

simion.early_access(8.2) -- http://simion.com/info/early_access.html

-- Load libraries.
local CON = simion.import '../contour/contourlib81.lua'  -- vector plotting
local MField = require 'simionx.MField'  -- Biot-Savart calculations.

-- Get PA instances.
local jinst  = simion.wb.instances[1]  -- -div M
local inst   = simion.wb.instances[3]  -- OH such that -grad OH = H*mu0 (if merge_m == 0)
                                       -- OB such that -grad OB = (H+M)*mu0 = B (if merge_m == 1)
local ominst = simion.wb.instances[2]  -- OM such that -grad OM = M*mu0 (only used if merge_m ~= 0)

-- Maps contour color numbers to specific PA instance numbers, for clarity.
simion.experimental.contour_color_instance{[1]={3}, [2]={1}}

-- This determines how the B-field is computed from H and M.
-- If 0, then we use B = -grad (mu0*OH) + M.
-- If 0, then we use B = -grad OB = - grad (mu0*OH + mu0*OM)
-- Setting this to 0 is the most general approach since
-- OM is multivalued around current loops, which causes issues in some regions.
adjustable merge_m = 0

-- vacuum permeability, T m/A
local MU0 = 4*math.pi*1E-7

-- gauss/Tesla conversion factor
local GAUSS_PER_TESLA = 10000

-- Magnetization (A/m) and point (x,y,z) mm
local function magnetization(x,y,z)
  local Mx
  if y^2+z^2 <= 20^2 and x >= 40-0.25 and x <= 60+0.25 then
    Mx = 1000   -- A/m
    -- Linear gradients on edges improve accuracy.
    -- We approximated that abrupt changes to M at some grid point
    -- occurs as a linear gradient over two grid units, one on each side
    -- of that point.
    if x <= 40+0.25 then
      Mx = Mx * (x - (40-0.25))/0.5
    elseif x >= 60-0.25 then
      Mx = Mx * (1 - (x - (60-0.25))/0.5)
    end
  else
    Mx = 0
  end
  return Mx,0,0
end

-- B-field in gauss.
-- Note: B = mu0*(H + M)
local function bfield(x,y,z)
  -- Highest priority magnetic PA instance (#3) contains H*mu0.
  -- simion.wb:bfield returns negative gradient of this.
  local bx,by,bz = simion.wb:bfield(x,y,z)

  -- If M*mu0 was not previously incorporated into H*mu0 in the PA, add it now.
  if merge_m == 0 then
    local Mx,My,Mz = magnetization(x,y,z)
    bx = bx + Mx*(MU0*GAUSS_PER_TESLA)
    by = by + My*(MU0*GAUSS_PER_TESLA)
    bz = bz + Mz*(MU0*GAUSS_PER_TESLA)
  end
  
  return bx,by,bz
end

function segment.flym()
  -- Solve for mu0*H.
  inst.pa:refine{charge=jinst.pa, convergence=1e-7}

  -- Optionally convert M*mu0 to a scalar potential and add it
  -- to the magnetic PA containing H*mu0.
  -- This results in the magnetic PA containing (H+M)* mu0 = B.
  -- Note, however, M*mu0 be converted to a scalar potential
  -- only within a subregion of the volume.
  -- It's safer to instead add M as a vector later.
  if merge_m ~= 0 then
    simion.experimental.spotential_from_vfield(ominst, magnetization, 10)
    ominst.pa:potentials_scale(0, MU0*GAUSS_PER_TESLA)
    local shift = 1.25  -- arbitrary potential shift to allow same contours regardless merge_m value
    for x,y,z in inst.pa:points() do
      if not inst.pa:electrode(x,y,z) then
        inst.pa:potential_add(x,y,z, ominst.pa:potential(x,y,z) + shift)
      end
    end
  end

  -- Optionally, compute the analogous B-field from an air-core solenoid.
  -- The air-core solenoid and uniformly magnetized cylinder should have
  -- identical B-fields.
  local bfield_solenoid = MField.solenoid_hoops {
    current = 1*20/1000,  -- 1 A/mm
    first = MField.vector(40,0,0),
    last  = MField.vector(60,0,0),
    radius = 20,
    nturns = 1000,
  }

  -- Plot B-field(s).
  simion.redraw_screen()  
  --bfield_solenoid:draw()
  CON.plot{{func=bfield, color=2}, {func=bfield_solenoid, color=3},
           z=0, mark=true,npoints=40}
  
  -- Check potentials, particularly near region where M changes
  -- (which is where the field is least accurate).
  for x=58,62,0.05 do
    print(x, (bfield(x,0,0)), (bfield_solenoid(x,0,0)))
  end
  
  run() -- continue any runs
end

-- Optionally make B-field visible to particle trajectories.
-- Careful: failure to do this in the case of merge_m == 0 would
--   make the particles see only the H*mu0 field, not the entire
--   B = (H+M)*mu0 field.
function segment.mfield_adjust()
  return bfield(ion_px_mm, ion_py_mm, ion_pz_mm)
end
