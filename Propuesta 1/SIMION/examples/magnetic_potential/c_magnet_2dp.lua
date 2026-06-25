--[[
 c_magnet_2dp.lua
 Solves magnetic field via magnetic vector potential (2D)
 and displays it.
 
 2012-01.
 (c) 2011-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()
simion.early_access(8.2) -- http://simion.com/info/early_access.html

-- Locate PA instances.
local muinst = simion.wb.instances[1]
local jzinst = simion.wb.instances[2]
local Azinst = simion.wb.instances[3]

-- Assign contour colors to specific PA instances for clearer visualization.
-- Maps color numbers of list of PA instance numbers.
simion.experimental.contour_color_instance{[1]={3}, [3]={1,2}, [10]={1}}

-- Accessing fields.
local bfield = simion.import 'maglib.lua'.make_bfield_vector(Azinst)
local function jfield(x,y,z)
  return 0,0,jzinst:potential_wc(x,y,z)
end

-- System parameters.
adjustable mu_inside = 1000   -- relative permeability of core
adjustable I = 2000    -- A
adjustable gap = 20    -- air gap half length, mm

-- Finds area (mm^2) in 2D PA instance having given value v.
local function find_area(inst, v)
  local area = 0
  local dA = inst.pa.dx_mm * inst.scale * inst.pa.dy_mm * inst.scale
  for x,y,z in inst.pa:points() do
    if inst.pa:potential(x,y,z) == v then area = area + dA end
  end
  return area
end

function segment.flym()
  -- Regenerate permeability and current densities in case
  -- "gap" variable changed.
  _G.gap = gap
  simion.command 'gem2pa c_magnet_2dp-mu.gem'
  simion.command 'gem2pa c_magnet_2dp-jz.gem'

  -- Rescale permeabilities based on "mu" variable.
  muinst.pa:load()
  for x,y,z in muinst.pa:points() do
    local mu = muinst.pa:potential(x,y,z)
    mu = (mu == 1) and 1 or mu_inside
    muinst.pa:potential(x,y,z, mu)
  end
  
  -- Rescale currents based on "I" variable.
  jzinst.pa:load()
  local area = find_area(jzinst, 1); print('area (mm^2)=', area)
  jzinst.pa:potentials_scale(0, I / area)
  
  -- Solve field.
  Azinst.pa:refine{potential_type='magnetic[A]',
      charge=jzinst.pa, permeability=muinst.pa, convergence=1e-5}
  
  simion.redraw_screen()
  
  -- Plot.
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot{func=bfield, npointsx=20, npointsy=20, mark=true, z=0}
  --CON.plot{func=jfield, npoints=40, mark=true, z=0}
  
  -- Analyze.
  print('B-field (Gauss) measured at (175,0,0) mm:', bfield(175,0,0))
  
  -- For comparison, approximate expected B-field by Ampere's law in integral form.
  -- see also http://en.wikipedia.org/wiki/Magnetic_core
  local nu_0 = (4*math.pi*1E-7)^-1
  local GAUSS_PER_TESLA = 10000
  local M_PER_MM = 1E-3
  local L_c = (100+gap)*2+150*2+100*2  -- length of path through core, mm
  local L_a = gap*2    -- length of path through air, mm
  local B_approx = 2*I / (nu_0*mu_inside^-1 * L_c + nu_0*L_a)/M_PER_MM*GAUSS_PER_TESLA
  print("Expected B using Ampere's law approximation (Gauss):", B_approx)
end
