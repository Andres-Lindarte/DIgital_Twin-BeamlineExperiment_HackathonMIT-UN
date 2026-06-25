--[[
 current_sphere_2dc.lua
 Solves magnetic vector potential and field
 for rotating sphere of charge.  2D cylindrical symmetry.
 See README.html for details.
 
 D.Manura, 2012-01,2011-12.
 (c) 2011 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()
simion.early_access(8.2) -- http://simion.com/info/early_access.html

-- System parameters.
adjustable R = 20  -- mm
adjustable omega = 1E+3 -- radians/sec
adjustable Q = 1 -- C

-- Plot in Excel. 1=yes, 0=no.
adjustable excel = 0

local convergence=1e-4

local CON = simion.import '../contour/contourlib81.lua'
local C = require 'simionx.Constants'
local MU = simion.import 'maglib.lua'

-- Gets PA instances.
local jzinst  = simion.wb.instances[1]
local psiinst = simion.wb.instances[2]
local jzpa    = jzinst.pa
local psipa   = psiinst.pa
local bfield = MU.make_bfield_vector(psiinst)
local jfield = MU.make_azimuthal_field(jzinst)
local Afield = MU.make_azimuthal_field(psiinst)

-- Maps contour color numbers to specific PA instance numbers, for clarity.
simion.experimental.contour_color_instance{[0]={1}}

--[[
 Build theoretical field (for comparison).
--]]
local function bfield_theo(x,y,z)
  x,y,z = y,z,x

  -- convert to spherical coordinates
  local r = math.sqrt(x^2+y^2+z^2) -- mm
  local theta = math.atan2(math.sqrt(x^2+y^2), z)
  local phi = math.atan2(y, x)
  
  -- convert to m
  local r_m = r*1E-3
  local R_m = R*1E-3
  
  local mu0 = C.MAGNETIC_CONSTANT_N_A
  
  -- note: SI units
  local br, btheta; local bphi = 0
  if r_m < R_m then -- inside sphere
    local c1 = mu0*omega*Q*(4*math.pi*R_m)^-1
    br     =   c1 * (1 - (3/5)*(r_m/R_m)^2) * math.cos(theta)
    btheta = - c1 * (1 - (6/5)*(r_m/R_m)^2) * math.sin(theta)
  else -- outside sphere
    local c1 = mu0/(4*math.pi*5)*Q*omega*R_m^2
    br =     (c1/r_m^3)*2*math.cos(theta)
    btheta = (c1/r_m^3)  *math.sin(theta)
  end
  
  -- convert to Gauss
  br = br * 1E+4
  btheta = btheta * 1E+4
  bphi = bphi * 1E-4
  
  --br=1 --btheta=1
  -- convert back to rectangular coordinates
  local sint,cost = math.sin(theta),math.cos(theta)
  local sinp,cosp = math.sin(phi)  ,math.cos(phi)
  local bx = sint*cosp*br + cost*cosp*btheta - sinp*bphi
  local by = sint*sinp*br + cost*sinp*btheta + cosp*bphi
  local bz = cost     *br - sint     *btheta
  
  by,bz,bx = bx,by,bz
  
  return bx,by,bz
end

--[[
 Build field from Biot-Savart calculation (for comparison).
--]]
local function build_biot_savart_field()
  local MField = require "simionx.MField"
  local current = Q*omega/(2*math.pi)  -- A
  local t = {}
  local totalcurrent = 0
  for x=-R+0.25,R,0.5 do
  for r=0+0.25,R,0.5 do
    if r^2 + x^2 <= R^2 then --IMPROVE accuracy?
      local thiscurrent = current*r
      totalcurrent = totalcurrent + thiscurrent
      t[#t+1] = {current=thiscurrent, x=x, radius=r}
    end
  end end
  local rescale = current / totalcurrent
  for i, v in ipairs(t) do
    t[i] = MField.hoop{current=v.current*rescale, center=MField.vector(v.x,0,0),
      normal=MField.vector(1,0,0), radius=v.radius}
  end
  local field = MField.combined_field(t)
  return field
end
local bfield_bs = build_biot_savart_field()


--[[
 Solve vector magnetic potential with Poisson solver.
--]]
function solve_fields()
  -- Define current density distributions.
  local volume = (4/3)*math.pi*R^3  -- volume, mm^3
  for x,y,z in jzpa:points() do
    local xc,yc,zc = x+0.5,y+0.5,z+0.5 -- center of cells for best accuracy
    local jm = 0
    if xc^2+yc^2+zc^2 <= R^2 then
      jm = (Q/volume)*(omega*yc)  -- current density magnitude, A/mm^2
    end
    jzpa:potential(x,y,z, jm) -- (A/mm^2)
  end

  -- Define boundary conditions in vector potential (actually psi = r*A_theta).
  -- Dirichlet (electrode) boundary conditions imply no flux across surface.
  -- Neumann (non-electrode) boundary conditions imply flux.
  local function set(pa, x,y,z, v,e)
    if e then pa:point(x,y,z, v,e) else pa:electrode(x,y,z, e) end
  end
  for x,y,z in psipa:points() do
    local is_electrode = x == psipa.nx-1 or y == 0 or y == psipa.ny-1
    set(psipa, x,y,z, 0,is_electrode)
  end
 
  -- Solve magnetic vector potential (Refine).
  psipa:refine{potential_type='magnetic[r*A]', convergence=convergence, charge=jzpa}
end


function segment.flym()
  solve_fields()
    
  simion.redraw_screen()

  -- Optionally plot Biot-Savart wires.
  -- bfield_bs:draw()

  -- Plot magnetic field vectors
  CON.plot{npoints=41, mark=true, z=0,
    {func=bfield, color=1},
    {func=bfield_theo, color=2},
    --{func=bfield_bs, color=3},
  }

  -- Optionally plot current density.
  CON.plot{func=jfield, npoints=41, mark=true, x=0, color=5}
  
  -- Optionally plot magnetic vector potential field.
  -- CON.plot{func=Afield, npoints=41, mark=true, x=0, color=6}
  
  -- As a test, compare calculated and theoretical fields.
  -- Note: there is some error at large radii due to the
  -- artifically small boundary condition used.
  local function norm(x,y,z) return math.sqrt(x^2+y^2+z^2) end
  local dataset = {header={'x', 'B', 'B_theo', 'B_bs'}}
  print(unpack(dataset.header))
  for z=0,99,1 do
    if z < 10 or z % 4 == 0 then
      local x,y = 0,0
      local b = norm(bfield(x,y,z))
      local b_theo = norm(bfield_theo(x,y,z))
      local b_bs = norm(bfield_bs(x,y,z))
      print(z, b, b_theo, b_bs)
      dataset[#dataset+1] = {z,b,b_theo,b_bs}
    end
  end
  if excel == 1 then
    simion.import'../excel/excellib.lua'.plot{dataset}
  end
end
