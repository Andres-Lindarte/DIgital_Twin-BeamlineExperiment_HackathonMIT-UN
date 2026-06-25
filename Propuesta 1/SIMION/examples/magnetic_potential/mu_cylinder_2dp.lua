--[[
mu_cylinder_2dp.lua
Solves magnetic field due to permeable cylinder.

D.Manura, 2012-01-05.
(c) 2011-2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

simion.workbench_program()
simion.early_access(8.2) -- http://simion.com/info/early_access.html

local mupa     = simion.wb.instances[1].pa  -- relative permeabilty constants
local Azpa     = simion.wb.instances[2].pa  -- magnetic vector potential
local Opa      = simion.wb.instances[3].pa  -- magnetic scalar potential
local Azpainst = simion.wb.instances[2]
local Opainst  = simion.wb.instances[3]
local bfield  = simion.import'maglib.lua'.make_bfield_vector(Azpainst, 'y')
local bfields = simion.import'maglib.lua'.make_bfield_scalar(Opainst, mupa, 'x')

-- Adjustable relative permeability constants inside and outside of cylinder.
adjustable mu_outside = 1
adjustable mu_inside = 5

-- Refine convergence objective (V).
adjustable convergence = 1E-5

local B0 = 100
local R = 10
local Cx,Cy = 0, 0

-- Theoretical field (for comparison).
local function btheo(x,y,z)
  local dy = y-Cy
  local dx = x-Cx
  local r = math.sqrt(dx^2 + dy^2)
  local mu_r = mu_outside/mu_inside
  if r < R then
    return B0*2/(1+mu_r),0,0
  end
  local m = (1 - mu_r)/(1 + mu_r)
  local Bx = B0*(1 + m*(dx^2 - dy^2)*R^2/r^4)
  local By = 2*B0*m*(x*y)*R^2/r^4
  local Bz = 0
  return Bx,By,Bz
end

local function solve_scalar()
  -- Refine.
  Opa:refine{convergence=convergence, permeability=mupa}
end

local function solve_vector()
  -- Refine.
  Azpa:refine{convergence=convergence, potential_type='magnetic[A]', permeability=mupa}
end

local function analyze() 
  -- Plot B-field (and theoretical B-field for comparison).
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot{
    npoints=41, mark=true, z=0, xl=-30,xr=30,yl=-30,yr=30,
    {func=bfield, color=1},
    {func=bfields, color=3},
    {func=btheo, color=2},
  }

  -- As a check, compared B-field along axis to theory.
  print('x', 'Bx_vector', 'Bx_scalar', 'Bx_theoretical')
  for x=0.5,15.5,1 do
    print(x, (bfield(x,0,0)), (bfields(x,0,0)), (btheo(x,0,0)))
  end
  for x=15.5,100,5 do
    print(x, (bfield(x,0,0)), (bfields(x,0,0)), (btheo(x,0,0)))
  end
  print('B(far)=',                bfield(99,0,0))  
  print('B(far)_s=',              bfields(99,0,0))  
  print('B(far)_theoretical=',    btheo(99,0,0))
  print('B(center)=',             bfield(0,0,0))
  print('B(center)_s=',           bfields(0,0,0))
  print('B(center)_theoretical=', btheo(0,0,0))
  -- Note: some error between measured and experimental is
  -- expected due to the finite boundaries.  This is seen in B(far).
  
  
  -- Update display.
  simion.redraw_screen()
end

-- Called by SIMION on Fly'm.
function segment.flym()
  -- Optionally replace permeability constants from adjustable variables.
  mupa:load()  -- reload original
  for xg,yg,zg in mupa:points() do
    local mu = mupa:potential(xg,yg,zg)
    mu = (mu == 1) and mu_outside or mu_inside
    mupa:potential(xg,yg,zg, mu)
  end
  
  solve_scalar()
  solve_vector()
  analyze()
end