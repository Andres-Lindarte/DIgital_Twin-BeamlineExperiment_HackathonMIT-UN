--[[
 current_sphere_3dp.lua
 Solves magnetic vector potential and field
 for rotating sphere of charge.  3D symmetry.
 See README.html for details.
 
 D.Manura, 2011-12.
 (c) 2011 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()
simion.early_access(8.2) -- http://simion.com/info/early_access.html

-- System parameters.
adjustable R = 20  -- mm
adjustable omega = 1E+3 -- radians/sec
adjustable Q = 1E+3 -- C

-- Resolve field. 1=yes, 0=no
adjustable solve = 1

-- Plot in Excel. 1=yes, 0=no
adjustable excel = 0

local C = require 'simionx.Constants'
local FA = simion.experimental

-- Get PA instances.
local Ainst= simion.wb.instances[1]
local jinst= simion.wb.instances[3]
local Axpa = simion.wb.instances[1].pa
local Aypa = simion.wb.instances[2].pa
local Azpa = simion.wb.instances[3].pa
local jxpa = simion.wb.instances[4].pa
local jypa = simion.wb.instances[5].pa
local jzpa = simion.wb.instances[6].pa
local Afa = FA.field_array {Axpa, Aypa, Azpa, antimirror='xy'}
local jfa = FA.field_array {jxpa, jypa, jzpa, antimirror='xy'}
local bfield = Afa:curl_field(Ainst)  -- B = curl A
local afield = Afa:to_field(Ainst)
local jfield = jfa:to_field(jinst)

--[[
 Build theoretical field (for comparison).
--]]
local function bfield_theo(x,y,z)
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
  for z=-R,R,0.5 do
  for rxy=1,R,0.5 do
    if rxy^2 + z^2 <= R^2 then --IMPROVE accuracy?
      --FIX: scale/weight current
      local thiscurrent = current*rxy
      totalcurrent = totalcurrent + thiscurrent
      t[#t+1] = {current=thiscurrent, z=z, radius=rxy}
    end
  end end
  local rescale = current / totalcurrent
  for i, v in ipairs(t) do
    t[i] = MField.hoop{current=v.current*rescale, center=MField.vector(0,0,v.z),
      normal=MField.vector(0,0,1), radius=v.radius}
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
  for x,y,z in jxpa:points() do
    local xc,yc,zc = x+0.5,y+0.5,z+0.5 -- center of cells for best accuracy
    local jx,jy,jz = 0,0,0
    if xc^2+yc^2+zc^2 <= R^2 then
      local ra = math.sqrt(xc^2+yc^2) -- distance from axis, mm
      local jm = (Q/volume)*(omega*ra)  -- current density magnitude, A/mm^2
      jx,jy,jz = -(yc/ra)*jm, (xc/ra)*jm, 0
    end
    jxpa:potential(x,y,z, jx)
    jypa:potential(x,y,z, jy)
    jzpa:potential(x,y,z, jz) -- (A/mm^2)
  end

  -- Define boundary conditions in vector potential.
  -- Dirichlet (electrode) boundary conditions imply no flux across surface.
  -- Neumann (non-electrode) boundary conditions imply flux.
  local function set(pa, x,y,z, v,e)
    if e then pa:point(x,y,z, v,e) else pa:electrode(x,y,z, e) end
  end
  for x,y,z in Axpa:points() do
    local is_electrode = x == Axpa.nx-1 or y == Axpa.ny-1 or z == Axpa.nz-1
    set(Axpa, x,y,z, 0, is_electrode or y==0)
    set(Aypa, x,y,z, 0, is_electrode or x==0)
    set(Azpa, x,y,z, 0, is_electrode)
  end

  -- Refine.
  local convergence=1e-4
  Afa:refine{charge=jfa, convergence=convergence}
  -- Afa:save('sphere3d-A.pa'); jfa:save('sphere3d-j.pa')
  
end


function segment.flym()
  if solve == 1 then
    solve_fields()
  end
  
  -- Optionally plot Biot-Savart wires.
  -- SOLVED.bfield_bs:draw()

  -- Plot magnetic field vectors
  simion.redraw_screen()
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot{npoints=81, mark=true, x=0,
    {func=bfield},
    {func=bfield_theo},  -- theoretical field (for comparison)
    --{func=bfield_bs},    -- Biot-Savart calculated field (for comparison).
  }

  -- Optionally plot current density.
  CON.plot{func=jfield, npoints=81, mark=true, z=0, color=5}

  -- As a test, compare calculated and theoretical fields.
  -- Note: there is some error at large radii due to the
  -- artifically small boundary condition used.
  local function mag(x,y,z) return math.sqrt(x^2+y^2+z^2) end
  local dataset = {header={'x', 'B', 'B_theo', 'B_bs'}}
  for z=0,100,1 do
    if z < 10 or z % 4 == 0 then
      local x,y = 0,0
      local b = mag(bfield(x,y,z))
      local b_theo = mag(bfield_theo(x,y,z))
      local b_bs = mag(bfield_bs(x,y,z))
      print(z, b, b_theo, b_bs)
      dataset[#dataset+1] = {x,b,b_theo,b_bs}
    end
  end
  if excel == 1 then
    simion.import'../excel/excellib.lua'.plot{dataset}
  end
end
