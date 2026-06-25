--[[
charged_dielectric_2dp.lua
Electric field calculation in a system where both the dielectric constants
and space-charge vary over space.  See README.html for details.  Briefly,

  For x in [0, x2],
  epsilon_r(x) = A * exp(B'*(x/x2))
  rho(x)       = C * sin((PI/2)*(x/x2))
  phi(0) = 0, phi(x2) = V2

D.Manura, 2012-01-05.
(c) 2011-2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

simion.workbench_program()

local painst = simion.wb.instances[3]
local dipa   = simion.wb.instances[1].pa  -- dielectric constants (initially empty)
local chpa   = simion.wb.instances[2].pa  -- charge density (C/mm^3) (initially empty)
local   pa   = simion.wb.instances[3].pa  -- electric potential

local CON = require 'simionx.Constants'

-- Refine convergence objective (V).
adjustable convergence = 1E-7

-- System parameters (see README).
-- Note: SI units below.
adjustable A = 1      -- unitless
adjustable Bprime = 1 -- unitless
adjustable C = 1E-5   -- C/m^3
local x2 = 0.01 -- m
local V2 = 10  -- V

-- Optional theoretical solution for potential (for comparison).
local function theo(x,y,z)  -- mm workbench coordinates
  local x_m = x*1E-3  -- m (SI units)
  local Ae = A * CON.ELECTRIC_CONSTANT_F_M
  local D = math.pi/(2*x2)
  local B = Bprime / x2
  if B == 0 then -- avoid division by zero
    return (1/(Ae*D^2))*(-(x_m/x2)*(C-V2*Ae*D^2) + C*sin(D*x_m))
  end
  local G = C/(Ae*D*(B^2+D^2))
  local F = (B==0) and 0 or (G*(B+D)*exp(-B*x2) - V2) / (exp(-B*x2) - 1)
  local E = G*B - F
  local phi = (E + G*(D*sin(D*x_m) - B*cos(D*x_m)))*exp(-B*x_m) + F
  return phi
end

-- Called by SIMION on Fly'm.
function segment.flym()
  -- Define dielectric and space-charge densities over the volume.
  -- (The GEM files were blank.)
  local D = math.pi/(2*x2)
  local B = Bprime / x2
  for xg,yg,zg in chpa:points() do
    local xc_wb,yc_wb,zc_wb = painst:pa_to_wb_coords(xg+0.5,yg+0.5,zg+0.5)
    local xc_m = xc_wb*1E-3
    dipa:potential(xg,yg,zg, A*exp(B*xc_m))
    chpa:potential(xg,yg,zg, (C*1E-9)*sin(D*xc_m)) -- C/mm^3
  end

  -- Solve for potential given dielectrics, space-charge, and
  -- potential boundary conditions.
  pa:refine{permittivity=dipa, charge=chpa, convergence=convergence}

  -- Update graphical view.
  simion.redraw_screen()
  
  -- Compare values to theory.
  print('x, vactual, vtheo, vtheo-vactual')
  for x=0,10 do -- mm
    local vtheo   = theo(x,0,0)
    local vactual = pa:potential_vc(x*10,0,0)
    print(x, vactual, vtheo, vtheo-vactual)
  end
end
