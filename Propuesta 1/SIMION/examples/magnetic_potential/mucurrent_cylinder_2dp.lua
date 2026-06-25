--[[
 mucurrent_cylinder_2dp.lua
 Solves magnetic vector potential (and B-field) for permeable cylinder with current
 and in traverse magnetic field, in 2D planar symmetry.
 See README.html for details.
 
 D.Manura, 2012-01,2011-12.
 (c) 2011-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()
simion.early_access(8.2) -- http://simion.com/info/early_access.html

-- whether to plot in Excel, 1=yes, 0=no.
adjustable excel = 0

-- Obtain PA instances.
local muinst = simion.wb.instances[1]  -- relative permeability
local jzinst = simion.wb.instances[2]  -- current density z component (j_z)
local Azinst = simion.wb.instances[3]  -- vector potential z component (A_z)
local Azpa   = Azinst.pa
local jzpa   = jzinst.pa
local mupa   = muinst.pa

-- Functions for accessing B-field and j-field from PA instances.
local bfield = simion.import 'maglib.lua'.make_bfield_vector(Azinst, 'y')
local jfield = function(x,y,z)
  return 0,0,jzinst:potential_wc(x,y,z)
end

-- Problem parameters.
local R = 10       -- radius, mm
local current = 100  -- cylinder current, A
local area = math.pi*R^2  -- cylinder cross sectional area, mm^2
local current_density = current/area  -- cylinder j, A/mm^2
local B0 = 100 -- Gauss
local MU0 = require 'simionx.Constants'.MAGNETIC_CONSTANT_N_A

-- Adjustable relative permeability constants inside and outside of cylinder.
adjustable mu_outside = 1
adjustable mu_inside = 5

-- Just for comparison, define theoretical magnetic field.
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

-- Solves A-field from j-field.
local function solve_fields()
  -- Optionally replace permeability constants from adjustable variables.
  mupa:load()  -- reload original
  for xg,yg,zg in mupa:points() do
    local mu = mupa:potential(xg,yg,zg)
    mu = (mu == 1) and mu_outside or mu_inside
    mupa:potential(xg,yg,zg, mu)
  end

  -- Define current density distributions.  Values sampled from centers of cells (0.5 gu).
  for x,y,z in jzpa:points() do
    local inside = ((x+0.5)*Azpa.dx_mm)^2+((y-200+0.5)*Azpa.dy_mm)^2 <= R^2
    jzpa:potential(x,y,z, inside and current_density or 0) -- (A/mm^2)
  end

  -- Refine.
  local convergence=1e-5
  Azpa:refine{potential_type='magnetic[A]', charge=jzpa, permeability=mupa, convergence=convergence}
  --Azpa:save()
  --jzpa:save()
end

function segment.flym()
  B0 = Azinst.pa:potential(0,Azinst.pa.ny-1,0)
  print('B0=', B0)

  -- Solve fields.
  solve_fields()
  
  simion.redraw_screen()
  
  -- Plot magnetic field and current density vectors.
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot{npoints=60, npointsz=2, mark=true, z=0,
    {func=bfield},
    {func=btheo}
  }
  CON.plot{func=jfield, npoints=80, npointsz=5, mark=true, color=5, vscale=0.7}
  
  -- As a test, compare calculated field to theoretical.
  local dataset = {header={'r (gu)', '|B| (Gauss)', '|B|_theo (Gauss)'}, title='Check of Field'}
  local function norm(vx,vy,vz) return math.sqrt(vx^2+vy^2+vz^2) end
  for x=0,100,1 do -- mm
    if x < 20 or x % 10 == 0 then
      local y,z = 0,0
      local bx,by,bz = bfield(x,y,z)
      local b = norm(bx,by,bz)
      local bxt,byt,bzt = btheo(x,y,z)
      local bt = norm(bxt,byt,bzt)
      print(x, b, bt)
      dataset[#dataset+1] = {x,b,bt}
    end
  end
  if excel == 1 then
    simion.import'../excel/excellib.lua'.plot(dataset)
  end
end
