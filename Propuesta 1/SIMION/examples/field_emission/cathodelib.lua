--[[
 cathodelib.lua - Cathode emission utility library.
 
 D.Manura, 2012-03-06
 (c) 2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

local CAT = {}


--[[
 Gets magnitude of vector (x,y,z).
--]]
function CAT.magnitude(x,y,z)
  return math.sqrt(x*x + y*y + z*z)
end


--[[
 Returns normalized vector of (x,y,z).
--]]
function CAT.norm(x,y,z)
  local m = CAT.magnitude(x,y,z)
  if m == 0 then return 0,0,0 end
  return x/m, y/m, z/m
end


--[[
 Gets lateral surface area of truncated cone.
 with height dx along axis and base radii r1 and r2.
--]]
function CAT.cone_area(dx, r1, r2)
  local s = math.sqrt(dx^2 + (r1-r2)^2)  -- laterial length
  return math.pi * (s * (r1+r2))
end

--[[
 Converts point (x,y,z) in PA grid units relative to PA origin
 to point (x,y,z) in PA grid units relative to PA instance origin
 (i.e. Xwo+,Ywo+,Zwo+ parameters on View > PAs tab > Positioning panel),
 if forward is true.  Does the reverse transformation if forward is false.
 `painst` is the PA instance object.
--]]
function CAT.pa_coords_reorigin(painst, x,y,z, forward)
  local dir = forward and -1 or 1
  x = x + dir*painst.ox/painst.pa.dx_mm
  y = y + dir*painst.oy/painst.pa.dy_mm
  z = z + dir*painst.oz/painst.pa.dz_mm
  return x,y,z
end

--[[
 Gets E-field (ex,ey,ez) in V/mm at point (x,y,z) in PA grid units
 in PA instance object `painst`.
 Note: Alternately, use `x,y,z = painst:wb_to_pa_coords(x,y,z)`
   to convert from PA to WB coords or use the new
   8.1.1.0 functions like `painst:field_wc(x,y,z)`
   for x,y,z in WB coordinates (mm) and returning V/mm units.
--]]
function CAT.efield(painst, x,y,z)
  local pa = painst.pa
  local ex,ey,ez = pa:field_vc(x,y,z) -- V/g
  ex = ex/(pa.dx_mm*painst.scale)
  ey = ey/(pa.dy_mm*painst.scale)
  ez = ez/(pa.dz_mm*painst.scale) -- V/mm
  return ex,ey,ez
end


--[[
 Gets potential (V) at point (x,y,z) in PA grid units
 in PA instance object `painst`.
--]]
function CAT.epotential(painst, x,y,z)
  return painst.pa:potential_vc(x,y,z)
end


--[[
 Reloads particle definitions from FLY2 file.
 WARNING: These use currently undocumented functions.
 Currently, this must be called from segment.flym not segment.initialize_run.
 `var` (if not nil) is table of variables that will be passed to the
   FLY2 file, which can access `var` as a global.
--]]
function CAT.reload_fly2(filename, var)
  local key
  for k,v in pairs(debug.getregistry()) do
    if type(v)=='table' and v.iterator then key = k; break end
  end
  assert(key)
  local ok, err = xpcall(function()
    _G.var = var -- set vars
    debug.getregistry()[key] = simion.iob2.load_fly2_file(filename)
  end, debug.traceback)
  _G.var = nil -- clear (the pcall ensures this is always executed.
  if not ok then error(err) end
end


--[[
 Gets charge weighting factor (CWF) for field E (V/mm).
 Uses a Fowler-Nordheim function.
 Returns current density in A/mm^2.
 There are many possible ways to define this.
 e.g. http://pdfserv.aip.org/JVTBD9/vol_26/iss_2/788_1.pdf
      http://en.wikipedia.org/wiki/Field_electron_emission
 Let's just use a simple one for now.
--]]
function CAT.fn_current_density(E, phi)
  E = E*1E-6  -- V/nm
  local a = 1.541434E-6  -- A eV V^-2   (first FN constant)
  local b = 6.830890  -- eV^(-3/2) V nm^-1   (second FN constant)
  local J = a*phi^-1*E^2*math.exp(-b*phi^(3/2)/E) -- A/nm^2
  return J*1E+12  -- A/mm^2
end


--[[
 Binary search.
 Find y such that gety(x) = ytarget and x1 <= x <= x2.
 Max 100 iterations.
--]]
local function binary_search(x1, x2, gety, ytarget)
  local y1 = gety(x1)
  local y2 = gety(x2)
  if y2 < y1 then x1,y1,x2,y2 = x2,y2,x1,y1 end -- swap
  for i=1,100 do
    local x = (x1+x2)/2
    local y = gety(x)
    if y < ytarget then
      x1 = x
    else
      x2 = x
    end
  end
  return (x1+x2)/2
end


--[[
 Finds closest position (x,y,z), in PA grid units, along line starting at
 point (x0,y0,z0) and having unit tangent vector (ux,uy,uz)
 such that potential equals v.
 Uses PA instance object `painst`.
 Maximum search out to +- 100 gu (in terms of x direction grid size),
 else raise error.
--]]
function CAT.get_position(painst, v, x0,y0,z0, ux,uy,uz)
  -- grid unit sizes
  local dx_mm = painst.pa.dx_mm
  local dy_mm = painst.pa.dy_mm
  local dz_mm = painst.pa.dz_mm
  
  -- rescale in terms of grid unit sizes in each direction.
  local ux,uy,uz = ux, uy*(dx_mm/dy_mm), uz*(dx_mm/dz_mm)

  local function getv(i) return CAT.epotential(painst, x0+ux*i, y0+uy*i, z0+uz*i) end
  local v0 = getv(0)
  local found
  for i=1,100 do
    for d=-1,1,2 do
      local vi = getv(d*i)
      if (v0 <= v and v <= vi) or (v0 >= v and v >= vi) then
        found = d*i
        break
      end
    end
    if found then break end
  end
  if not found then error('potential '..v..' not found') end
  found = binary_search(found+(found>0 and -1 or 1), found, getv, v)
  return x0+ux*found, y0+uy*found, z0+uz*found
end


--[[
 Determines if electode surface is in the same or opposite
 direction of the electric field from point (x0,y0,z0).
 (x0,y0,z0) is in PA grid units and is just outside an electrode.
 `painst` is the PA instance object.
 Returns 1 if same or -1 if opposite.
 Fails if no electrode found within 100 grid units.
--]]
function CAT.electrode_direction(painst, x0,y0,z0)
  local pa = painst.pa
  local ux,uy,uz = CAT.norm(CAT.efield(painst, x0,y0,z0))
  local function round(x) return math.floor(x+0.5) end
  local function elect(i)
    local x,y,z = round(i*ux), round(i*uy), round(i*uz)
    return pa:electrode(x,y,z)
  end
  for i=1,100 do
  for d=-1,1,2 do
    if elect(i*d) then
      return d
    end
  end end
  error 'electrode not found'
end


--[[
 Calls f(x2,y2,z2) for each of n points along equipotential
 contour in Z plane in PA instance object `painst`.
 Points are spaced approximately `length/n`
 grid units appart, starting with (x1,y1,z1) gu exclusive.
 Use negative `length` to walk in reverse direction.
--]]
function CAT.walk_potential(painst, x1,y1,z1, length, n, f)
  local d_mm = length/n
  local v0 = CAT.epotential(painst, x1,y1,z1)

  -- grid unit sizes
  local dx_mm = painst.scale * painst.pa.dx_mm
  local dy_mm = painst.scale * painst.pa.dy_mm
  local dz_mm = painst.scale * painst.pa.dz_mm
  
  for i=1,n do
    local e0x,e0y,e0z = CAT.efield(painst, x1,y1,z1)
    local ux,uy,uz = CAT.norm(e0y,-e0x,0)
    local x2,y2,z2 = x1+ux*d_mm/dx_mm, y1+uy*d_mm/dy_mm, z1+uz*d_mm/dz_mm
    local u1x,u1y,u1z = CAT.norm(CAT.efield(painst, x2,y2,z2))
    x2,y2,z2 = CAT.get_position(painst, v0, x2,y2,z2, u1x,u1y,u1z)
    f(x2,y2,z2)
    x1,y1,z1 = x2,y2,z2
  end
end


--[[
 For the Z plane equipotential contour curve starting at point (x1,y1,z1) in
 PA grid units (relative to working origin of PA instance object `painst`),
 partition this curve into `nsegments` number of segments of
 approximate size `d=cathode_length/nsegments` mm, and call function `f`
 for each segment mid-point.
 Calls to f are of the form f(xc,yc,zc, ucx,ucy,ucz, area, V,E), where
   (x,y,z) is particle starting point in PA grid units, relative to the
     PA instance working origin.
   (ux,uy,uz) is a unit vector perpendicular to the equipotential
     contour and with direction away from any nearby electrode.
     Orientation is in PA coordinates.
   area is cathode segment area (mm^2), assuming 2D cylindrical symmetry,
     with rotating cathode segment around x axis (in PA coordinates).
   V is potential at (x,y,z) in Volts.
   E is the magnitude of the electric field at (x,y,z) in V/mm.
 Use negative cathode_length to walk the curve in the reverse direction.
--]]
function CAT.walk_cathode(painst, x1,y1,z1, cathode_length, nsegments, f)
  x1,y1,z1 = CAT.pa_coords_reorigin(painst, x1,y1,z1, false)

  -- grid unit sizes
  local dx_mm = painst.scale * painst.pa.dx_mm
  local dy_mm = painst.scale * painst.pa.dy_mm
  --local dz_mm = painst.scale * painst.pa.dz_mm
  
  local v0 = CAT.epotential(painst, x1,y1,z1)  -- contour potential
  local dir = CAT.electrode_direction(painst, x1,y1,z1)

  CAT.walk_potential(painst, x1,y1,z1, cathode_length, nsegments, function(x2,y2,z2)
    local xc,yc,zc = (x1+x2)/2, (y1+y2)/2, (z1+z2)/2  -- mid-point
    local ucx,ucy,ucz = CAT.norm(CAT.efield(painst, xc,yc,zc))
    local xc,yc,zc = CAT.get_position(painst, v0, xc,yc,zc, ucx,ucy,ucz)
    local ucx,ucy,ucz = CAT.norm(CAT.efield(painst, xc,yc,zc))
    if dir == -1 then ucx,ucy,ucz = -ucx,-ucy,-ucz end  -- away from electrode
    local V = CAT.epotential(painst, xc,yc,zc)             -- local potential, V
    local E = CAT.magnitude(CAT.efield(painst, xc,yc,zc))  -- local field, V/mm
    local area = CAT.cone_area((x1-x2)*dx_mm,y1*dy_mm,y2*dy_mm) --segment, mm^2

    xc,yc,zc = CAT.pa_coords_reorigin(painst, xc,yc,zc, true)

    f(xc,yc,zc, ucx,ucy,ucz, area, V,E)
    
    x1,y1,z1 = x2,y2,z2
  end)
end


--[[
 Sets the repulsion amount (A) for use in the beam method of charge repulsion.
--]]
function CAT.set_beam_repulsion_amount(current)
  -- We need to temporarily change to the Beam repulsion method to do this.
  local last_repulsion = sim_repulsion  -- preserve
  local last_grouped = sim_grouped
  sim_repulsion = 'beam'
  sim_repulsion_amount = current
  sim_repulsion = last_repulsion  -- restore
  sim_grouped = last_grouped
end


return CAT
