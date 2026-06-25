--[[
sphere_3dp.lua
Solves magnetic field due to permeable sphere.
3D symmetry.

D.Manura, 2012-01-05.
(c) 2011-2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

simion.workbench_program()
simion.early_access(8.2) -- http://simion.com/info/early_access.html

-- Adjustable dielectric constants inside and outside of cylinder.
adjustable mu_inside  = 5
adjustable mu_outside = 1

-- Refine convergence objective (V).
adjustable convergence = 1E-5

local Cx,Cy,Cz=0,0,0
local B0 = 100
local R = 10

-- Get PA instances.
local mupa = simion.wb.instances[1].pa  -- relative permeability
local Opa  = simion.wb.instances[2].pa  -- magnetic scalar potential
local Oinst= simion.wb.instances[2]
local bfield = simion.import'maglib.lua'.make_bfield_scalar(Oinst, mupa, 'x')

-- DISABLED: magnetic vector potential with permeability not supported in 3D arrays.
--[[
local FA = simion.experimental
local Axpa = simion.wb.instances[2].pa  -- magnetic vector potential x
local Aypa = simion.wb.instances[3].pa  -- magnetic vector potential y
local Azpa = simion.wb.instances[4].pa  -- magnetic vector potential z
local Ainst= simion.wb.instances[2]
local Afa = FA.field_array {Axpa,Aypa,Azpa, antimirror='yz'}
local bfieldv = Afa:curl_field(Ainst); -- B = curl A
--]]

-- Theoretical field (for comparison).
local function btheo(x,y,z)
  local dx,dy,dz = x-Cx, y-Cy, z-Cz
  local r,az,el = rect3d_to_polar3d(dz,dx,dy)
  
  local theta = math.rad(90 - el)
  
  local mu_r = mu_outside/mu_inside
  if r < R then
    return B0*3/(1+2*mu_r),0,0
  end
  local sint = math.sin(theta)
  local cost = math.cos(theta)
  local f = (1 - mu_r)/(1 + 2*mu_r)*(R/r)^3
  local Br     =  B0*cost*( 1 + 2*f)
  local Btheta = -B0*sint*(-1 + f)
  local Bz,Bx,By = azimuth_rotate(az, elevation_rotate(el, Br,Btheta,0))
  return Bx,By,Bz
end


local function analyze()
  -- Plot B-field (and theoretical B-field for comparison).
  simion.redraw_screen()
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot{npoints=41, mark=true, z=0, xl=-30,xr=30,yl=-30,yr=30,
    {func=bfield, color=1},
    --DISABLED: {func=bfields, color=3},
    {func=btheo, color=2}
  }

  -- As a check, compared B-field along axis to theory.
  print('x', 'Bx', 'Bx_theoretical')
  for x=0.5,15.5,1 do
    print(x,(bfield(x,0,0)), (btheo(x,0,0)))
  end
  for x=15.5,100,5 do
    print(x,(bfield(x,0,0)), (btheo(x,0,0)))
  end
  print('B(far)=', bfield(99,0,0))  
  print('B(far)_theoretical=', btheo(99,0,0))
  print('B(center)=', bfield(0,0,0))
  print('B(center)_theoretical=', btheo(0,0,0))
  -- Note: some error between measured and experimental is
  -- expected due to the finite boundaries.  This is seen in B(far).
  
end

function segment.flym()
  -- Optionally replace relative permeability constants from adjustable variables.
  mupa:load()  -- reload original
  for xg,yg,zg in mupa:points() do
    local mu = mupa:potential(xg,yg,zg)
    mu = (mu == 1) and mu_outside or mu_inside
    mupa:potential(xg,yg,zg, mu)
  end

  -- Solve magnetic scalar potential (Refine).
  Opa:refine{permeability=mupa, convergence=convergence}

  -- Solve magnetic vector potential (Refine).
  -- Warning: permeability with 3D magnetic vector potential isn't supported yet,
  -- so it's disabled
  -- Afa:refine{potential_type='magnetic[A]', permeability=mupa, convergence=convergence}

  analyze()
end
