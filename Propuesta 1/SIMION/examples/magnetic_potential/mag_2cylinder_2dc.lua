--[[
 mag_2cylinder_2dc.lua
 Solves magnetic B-field of two co-axial uniformly magnetized cylinders.
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
local Mxinst = simion.wb.instances[1]  -- M_x
local jinst  = simion.wb.instances[2]  -- -div M
local inst   = simion.wb.instances[3]  -- OH such that -grad OH = H*mu0

-- Maps contour color numbers to specific PA instance numbers, for clarity.
simion.experimental.contour_color_instance{[0]={1}, [2]={3}}

-- vacuum permeability, T m/A
local MU0 = 4*math.pi*1E-7

-- conversion factors
local GAUSS_PER_TESLA = 10000   -- gauss/tesla
local M_PER_MM = 0.001          -- m/mm

-- M-field in A/mm
local function Mfield(x,y,z)
  local hgu = Mxinst.pa.dx_mm * Mxinst.scale * 0.5  -- 1/2 gu adjustment should be more accurate
  local Mx,My,Mz = Mxinst:potential_wc(x-hgu,y-hgu,z-hgu), 0, 0
  return Mx,My,Mz
end

-- B-field in gauss.
-- Note: B = mu0*(H + M)
local function bfield(x,y,z)
  -- Highest priority magnetic PA instance (#3) contains H*mu0.
  -- simion.wb:bfield returns negative gradient of this.
  local bx,by,bz = simion.wb:bfield(x,y,z)

  -- Add M*mu0 to H*mu0.
  local Mx,My,Mz = Mfield(x,y,z)
  bx = bx + (Mx/M_PER_MM)*(MU0*GAUSS_PER_TESLA)
  by = by + (My/M_PER_MM)*(MU0*GAUSS_PER_TESLA)
  bz = bz + (Mz/M_PER_MM)*(MU0*GAUSS_PER_TESLA)
  
  return bx,by,bz
end

function segment.flym()
  -- Compute -div M.  Note: the negative gradient can be reused for this calculation.
  for x,y,z in jinst.pa:points() do
    local fixup = (-1)*(-1) / Mxinst.pa.ng
    local dMx_dx, _, _ = Mxinst.pa:field_vc(x,y,z)
    dMx_dx = dMx_dx * fixup  -- convert to A/mm^2
    local dMy_dy = 0
    local dMz_dz = 0
    local j = dMx_dx + dMy_dy + dMz_dz  -- div M  (A/mm^2)
    jinst.pa:potential(x,y,z, j)
  end

  -- Solve for mu0*H.
  inst.pa:refine{charge=jinst.pa, convergence=1e-7}

  -- Optionally, compute the analogous B-field from coaxial air-core solenoids.
  -- The air-core solenoids and uniformly magnetized cylinders should have
  -- identical B-fields.
  local bfield_solenoid = MField.combined_field {
    MField.solenoid_hoops {
      current = 1*20/1000,  -- 1 A/mm
      first = MField.vector(75,0,0),
      last  = MField.vector(95,0,0),
      radius = 20,
      nturns = 1000,
    };
    MField.solenoid_hoops {
      current = 1*20/1000,  -- 1 A/mm
      first = MField.vector(105,0,0),
      last  = MField.vector(125,0,0),
      radius = 20,
      nturns = 1000,
    };
  }

  -- Plot B-field(s).
  simion.redraw_screen()  
  --bfield_solenoid:draw()
  CON.plot{{func=bfield, color=2},
           {func=bfield_solenoid, color=3},
           --{func=Mfield, color=4},
           z=0, mark=true,npoints=60}
  -- CON.plot{func=bfield, color=2, z=0, mark=true,npoints=40, xl=90,xr=110,yl=15,yr=25} -- fringe region
  
  -- Check potentials, particularly near region where M changes
  -- (which is where the field is least accurate).
  for x=58,62,0.05 do
    print(x, (bfield(x,0,0)), (bfield_solenoid(x,0,0)))
  end
  
  run() -- continue any runs
end
