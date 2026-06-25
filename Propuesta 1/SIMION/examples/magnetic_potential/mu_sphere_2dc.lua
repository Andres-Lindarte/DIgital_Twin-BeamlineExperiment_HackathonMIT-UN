--[[
mu_sphere_2dc.lua
Solves magnetic field due to permeable sphere.

D.Manura, 2012-01-05.
(c) 2011-2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

simion.workbench_program()
--simion.early_access(8.2) -- http://simion.com/info/early_access.html

-- Adjustable relative permeability constants inside and outside of cylinder.
adjustable mu_inside = 10
adjustable mu_outside = 1

-- Refine convergence objective (V).
adjustable convergence = 1E-5

-- System parameters.
local Cx,Cy,Cz=0,0,0
local B0 = 100
local R = 10


-- PA instances.
local muinst  = simion.wb.instances[1]  -- relative permeability
local Azinst  = simion.wb.instances[2]  -- magnetic vector potential, azimuthal
local Oinst   = simion.wb.instances[3]  -- magnetic scalar potential
local mupa    = muinst.pa
local Azpa    = Azinst.pa
local Opa     = Oinst.pa
local bfield = simion.import 'maglib.lua'.make_bfield_vector(Azinst)
local bfields = simion.import'maglib.lua'.make_bfield_scalar(Oinst, mupa, 'x')

-- Map color numbers to PA instance numbers for clarity.
simion.experimental.contour_color_instance{[1]={2}, [0]={1}, [10]={3}}

-- Theoretical field (for comparison).
local function btheo(x,y,z)
  local dx,dy,dz = x-Cx, y-Cy, z-Cz
  local r = rect3d_to_polar3d(dz,dx,dy)
  local p = math.sqrt(dy^2+dz^2)
  
  local mu_r = mu_outside/mu_inside
  if r < R then
    return B0*3/(1+2*mu_r),0,0
  end

  local m = (1 - mu_r)/(1 + 2*mu_r)
  local Bx = B0*(1 + m*(2*x^2 - p^2)*R^3/r^5)
  local Bp = B0*3*m*x*p*R^3*r^-5
  
  local By = Bp*(p == 0 and 0 or dy/p)
  local Bz = Bp*(p == 0 and 0 or dz/p)

  return Bx,By,Bz
end

-- Called by SIMION on Fly'm.
function segment.flym()
  -- Optionally replace mu from adjustable variables.
  mupa:load()  -- reload original
  for xg,yg,zg in mupa:points() do
    local mu = mupa:potential(xg,yg,zg)
    mu = (mu == 1) and mu_outside or mu_inside
    mupa:potential(xg,yg,zg, mu)
  end

  -- Refine, solving scalar magnetic potential.
  Opa:refine{convergence=convergence, permeability=mupa}
  
  -- Refine, solving magnetic vector potential
  -- (as an alternative, for comparison).
  Azpa:refine{convergence=convergence, potential_type='magnetic[r*A]', permeability=mupa}
  
  -- Plot.
  simion.redraw_screen()
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot{
    npoints=41, mark=true, npoints=41, mark=true, z=0, xl=-30,xr=30,yl=-30,yr=30,
    {func=bfield, color=1},
    {func=bfields, color=3},
    {func=btheo, color=2},
  }
  simion.redraw_screen()

  -- Analyze results.
  -- As a check, compare B-field along axis to theory.
  print('x', 'Bx_vector', 'Bx_scalar', 'Bx_theoretical')
  for x=0.5,15.5,1 do
    print(x,(bfield(x,0,0)), (bfields(x,0,0)), (btheo(x,0,0)))
  end
  for x=15.5,100,5 do
    print(x,(bfield(x,0,0)), (bfields(x,0,0)), (btheo(x,0,0)))
  end
  print('B(far)=', bfield(99,0,0))
  print('B(far)_s=', bfields(99,0,0))
  print('B(far)_theoretical=', btheo(99,0,0))
  print('B(center)=', bfield(0,0,0))
  print('B(center)_s=', bfields(0,0,0))
  print('B(center)_theoretical=', btheo(0,0,0))
  
end


