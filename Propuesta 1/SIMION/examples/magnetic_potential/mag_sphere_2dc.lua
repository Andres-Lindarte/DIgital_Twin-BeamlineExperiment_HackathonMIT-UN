--[[
 mag_sphere_2dc.lua
 Solves magnetic B-field of uniformly magnetized sphere.
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
local inst   = simion.wb.instances[2]  -- OH such that -grad OH = H*mu0

-- Maps contour color numbers to specific PA instance numbers, for clarity.
simion.experimental.contour_color_instance{[2]={2}, [1]={1}}

-- vacuum permeability, T m/A
local MU0 = 4*math.pi*1E-7

-- gauss/Tesla conversion factor
local GAUSS_PER_TESLA = 10000

-- magnetization inside sphere (must be the same as in mag_sphere_2dc.gem)
local M0 = 1000  -- A/m

-- sphere radius (must be the same as in mag_sphere_2dc.gem)
local R = 10 -- mm

-- Draws circle with origin (x0,y0) and radius R (mm) in XY plane.
local function plot_circle(x0,y0, R)
  for theta=0,359 do
    local x1 = x0 + R*math.cos(math.rad(theta))
    local y1 = y0 + R*math.sin(math.rad(theta))
    local x2 = x0 + R*math.cos(math.rad(theta+1))
    local y2 = y0 + R*math.sin(math.rad(theta+1))
    simion.experimental.plot_line_segment(x1,y1,0, x2,y2,0)
  end
end

-- Magnetization (A/m) and point (x,y,z) mm
local function magnetization(x,y,z)
  local r = math.sqrt(x^2+y^2+z^2)
  if r < R-0.25 then
    return M0,0,0
  elseif r <= R then  -- gradually reduce over 1 gu (like in .gem) improves accuracy
    return M0*(1 - (r - (R-0.25)))*0.5,0,0
  else
    return 0,0,0
  end
end

-- Theoretical B-field, merely for comparison to calculated B-field.
-- Based on Griffiths Example 6.1.
local function btheo(x, y, z)
  local r = math.sqrt(x^2+y^2+z^2)
  if r <= R then
    return (2/3)*MU0*GAUSS_PER_TESLA*M0
  else
    local m_x = (4/3)*math.pi*(R*1E-3)^3*M0 -- dipole, A*m^2
    local rx,ry,rz = x/r, y/r, z/r
    return GAUSS_PER_TESLA*(MU0/4/math.pi)*(r*1E-3)^-3*(3*m_x*rx*rx - m_x),
           GAUSS_PER_TESLA*(MU0/4/math.pi)*(r*1E-3)^-3*(3*m_x*rx*ry - 0),
           GAUSS_PER_TESLA*(MU0/4/math.pi)*(r*1E-3)^-3*(3*m_x*rx*rz - 0)
  end
end

-- B-field in gauss.
-- Note: B = mu0*(H + M)
local function bfield(x,y,z)
  -- Highest priority magnetic PA instance (#3) contains H*mu0.
  -- simion.wb:bfield returns negative gradient of this.
  local bx,by,bz = simion.wb:bfield(x,y,z)
  if x < 0 then bx,by,bz = -bx,-by,-bz end  -- antimirror x
  
  -- Add H*mu0.
  local Mx,My,Mz = magnetization(x,y,z)
  bx = bx + Mx*(MU0*GAUSS_PER_TESLA)
  by = by + My*(MU0*GAUSS_PER_TESLA)
  bz = bz + Mz*(MU0*GAUSS_PER_TESLA)
  
  return bx,by,bz
end


function segment.flym()
  -- Solve for mu0*H.
  inst.pa:refine{charge=jinst.pa, convergence=1e-7}

  -- Optionally, compute the analogous B-field from an air-core solenoid.
  -- The air-core solenoid and uniformly magnetized cylinder should have
  -- identical B-fields.
  --[[
  local bfield_solenoid = MField.solenoid_hoops {
    current = 1*20/1000,  -- 1 A/mm
    first = MField.vector(40,0,0),
    last  = MField.vector(60,0,0),
    radius = 20,
    nturns = 1000,
  }
  --]]

  -- Plot B-field(s).
  simion.redraw_screen()  
  --bfield_solenoid:draw()
  CON.plot{{func=bfield, color=2}, {func=btheo, color=3},
           z=0, mark=true,npoints=40}
  plot_circle(0,0, R)
  
  -- Check potentials, particularly near region where M changes
  -- (which is where the field is least accurate).
  for x=8,12,0.1 do
    print(x, (bfield(x,0,0)), (btheo(x,0,0)))
  end
  
  
  run() -- continue any runs
end


-- Optionally make B-field visible to particle trajectories.
-- Without this, particles will only see H*mu0 field.
function segment.mfield_adjust()
  return bfield(ion_px_mm, ion_py_mm, ion_pz_mm)
end
