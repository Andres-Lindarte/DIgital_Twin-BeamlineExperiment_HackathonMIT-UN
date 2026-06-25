--[[
 current_cylinder_2dp.lua
 Solves magnetic vector potential (and B-field) for cylinder of current,
 in 2D planar symmetry.
 See README.html for details.
 
 D.Manura, 2012-01,2011-12.
 (c) 2011-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()
simion.early_access(8.2) -- http://simion.com/info/early_access.html

-- Problem parameters.
adjustable R = 20       -- radius, mm
adjustable current = 1  -- cylinder current, A

-- whether to plot in Excel, 1=yes, 0=no.
adjustable excel = 0

-- Obtain PA instances.
local jzinst = simion.wb.instances[1]  -- current density z component (j_z)
local Azinst = simion.wb.instances[2]  -- vector potential z component (A_z)
local Azpa   = Azinst.pa
local jzpa   = jzinst.pa

-- Functions for accessing B-field and j-field from PA instances.
local bfield = simion.import 'maglib.lua'.make_bfield_vector(Azinst)
local function jfield(x,y,z) return 0,0,jzinst:potential_wc(x,y,z) end


-- Just for comparison, define theoretical magnetic field.
local C = require 'simionx.Constants'
local function btheo(x,y,z)
  local r = math.sqrt(x^2+y^2)
  if r == 0 then return 0,0,0 end
  local b = C.MAGNETIC_CONSTANT_N_A * current/(2*math.pi*(r*1E-3)) * 1E+4
  if r < R then b = b * (r/R)^2 end
  local Bx = b * -y/r
  local By = b *  x/r
  local Bz = 0
  return Bx,By,Bz
end


-- Solves A-field from j-field.
local function solve_fields()
  -- Define current density distributions.
  -- Values sampled from centers of cells (0.5 gu) for best accuracy.
  local area = math.pi*R^2  -- cylinder cross sectional area, mm^2
  local current_density = current/area  -- cylinder j, A/mm^2
  for x,y,z in jzpa:points() do
    if ((x+0.5)*Azpa.dx_mm)^2+((y+0.5)*Azpa.dy_mm)^2 <= R^2 then
      jzpa:potential(x,y,z, current_density) -- (A/mm^2)
    end
  end

  -- Define boundary conditions in vector potential.
  -- Dirichlet (electrode) boundary conditions imply no flux across surface.
  -- Neumann (non-electrode) boundary conditions imply flux.
  for x,y,z in Azpa:points() do
    local is_electrode = x == Azpa.nx-1 or y == Azpa.ny-1
    Azpa:point(x,y,z, 0, is_electrode)
  end

  -- Refine.
  local convergence=1e-5
  Azpa:refine{charge=jzpa, convergence=convergence}
  -- Azpa:save(); jzpa:save()
end


function segment.flym()
  -- Solve fields.
  solve_fields()
  
  -- Plot magnetic field and current density vectors.
  simion.redraw_screen()
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot{npoints=20, npointsz=2, mark=true, scale='median',
    {func=bfield},
    {func=btheo}
  }
  CON.plot{func=jfield, npoints=80, npointsz=5, mark=true, color=5, vscale=0.7}
  
  -- As a test, compare calculated field to theoretical.
  local dataset = {header={'r (mm)', '|B| (Gauss)', '|B|_theo (Gauss)'}, title='Check of Field'}
  local function norm(x,y,z) return math.sqrt(x^2+y^2+z^2) end
  print(unpack(dataset.header))
  for x=0,200,2 do -- mm
    if x < 20 or x % 10 == 0 then
      local y,z = 0,0
      local b      = norm(bfield(x,y,z))
      local b_theo = norm(btheo(x,y,z))
      print(x, b, b_theo)
      dataset[#dataset+1] = {x,b,b_theo}
    end
  end
  if excel == 1 then
    simion.import'../excel/excellib.lua'.plot(dataset)
  end

  -- run()
end
