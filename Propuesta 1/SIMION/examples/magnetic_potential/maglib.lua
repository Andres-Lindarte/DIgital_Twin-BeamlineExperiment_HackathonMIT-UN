--[[
 Various utility functions useful for dealing with magnetic fields
 and magnetic (vector or scalar) potential.
 D.Manura, 2012-02,2012-01.
 (c) 2011-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

local M = {}

simion.early_access(8.2) -- http://simion.com/info/early_access.html

--[[
 Apply antimirroring to vector (vx,vy,vz) origined at point (x,y,z).
--]]
local antimirror_x = {['x']=1, ['xy']=1, ['xz']=1, ['xyz']=1}
local antimirror_y = {['y']=1, ['xy']=1, ['yz']=1, ['xyz']=1}
local antimirror_z = {['z']=1, ['xz']=1, ['yz']=1, ['xyz']=1}
local function anti(antimirror, x,y,z, vx,vy,vz)
  local sum =
    (x < 0 and antimirror_x[antimirror] or 0) +
    (y < 0 and antimirror_y[antimirror] or 0) +
    (z < 0 and antimirror_z[antimirror] or 0)
  if sum == 1 or sum == 3 then vx,vy,vz = -vx,-vy,-vz end
  return vx,vy,vz
end

--[[
 Computes B-field from magnetic scalar potential `painst` and
 relative magnetic permeability mu.  In 2D planar or 3D coords.
 painst is a PA instance object.
 muf is a function of the form: mu = muf(x,y,z) in workbench coordinates.
   if muf return nil, this is interpreted as 1.
 Returns 0,0,0 if points outside PA instane volume.
--]]
function M.bfield_scalar(painst, muf, antimirror, x,y,z)
  local mu = muf and muf(x,y,z) or 1
  
  local xg,yg,zg = painst:wb_to_pa_coords(x,y,z)
  if not painst.pa:inside_vc(xg,yg,zg) then return 0,0,0 end
  local ex,ey,ez = painst.pa:field_vc(xg,yg,zg)
  local Bx,By,Bz = ex*mu, ey*mu, ez*mu
  Bx,By,Bz = anti(antimirror, xg,yg,zg, Bx,By,Bz)
  if painst then Bx,By,Bz = painst:pa_to_wb_orient(Bx,By,Bz) end
  return Bx,By,Bz
end
local bfield_scalar = M.bfield_scalar

--[[
 Returns function `f` representing values in PA object `pa`.
 `pa` if omitted defaults to `painst.pa` where `painst` is a PA instance object.
 `f` has the form `v = f(x,y,z)` where `(x,y,z)` are in workbench coordinates.
 PA grid point (x,y,z) is assumed to represent region (x,y,z) inclusive
 to (x+1,y+1,z+1) exclusive.
 Therefore, this function may be used for things like charge density
 and permeability where values in the PA object represent the average value
 in the entire cell.  This function should not be used for things like
 electric potential where values in the PA object represent the value
 at the cell vertex.
 Returns nil if point outside array.
--]]
function M.make_cell_scalar(painst, pa)
  pa = pa or painst.pa
  return function(x,y,z)
    local xa,ya,za = painst:pa_to_array_coords(painst:wb_to_pa_coords(x,y,z))
    -- mu inside current cell
    local xi = math.floor(xa)
    local yi = math.floor(ya)
    local zi = math.floor(za)
    if xi == pa.nx then xi=xi-1 end
    if yi == pa.ny then yi=yi-1 end
    if zi == pa.nz and pa.nz>1 then zi=zi-1 end
    if not pa:inside_vc(xi,yi,zi) then
      return nil
    end
    val = pa:potential(xi,yi,zi)
    return val
  end
end

--[[
 Returns function `f` representing B-field given
 PA instance object (painst) of magnetic scalar potential
 and relative permeability mu.
 mu is a function or a PA object or nil (relative permeability defaults to 1 if nil).
 `f` maps point (x,y,z) in workbench coordinates (mm) to
 vector (Bx,By,Bz) in gauss.
--]]
function M.make_bfield_scalar(painst, mu, antimirror)
  if type(mu) == 'userdata' then -- PA
    mu = M.make_cell_scalar(painst, mu)
  end
  return function(x,y,z)
    return bfield_scalar(painst, mu, antimirror, x,y,z)
  end
end

--[[
 Gets magnetic B-field vector (Bx,By,Bz) in gauss at point
 (x,y,z) in PA volume grid units.  `psipa` is a PA object containing the
 psi = r*A_theta, for radius r and azimuthal component of
 magnetic vector potential, A_theta.
--]]
function M.bfield_vector_cyl(psipa, x,y,z)
  if math.abs(y) < 1 then y = 1 end -- near axis approximation
  local ex,ey,ez = psipa:field_vc(x,y,z)
  local Bx,By,Bz = 1/y * -ey, 1/y * ex, 0
  return Bx,By,Bz
end

--[[
 Same as bfield_vector_cyl but uses PA instance with (x,y,z) in
 workbench coordinates in mm.
--]]
function M.bfield_vector_cyl_inst(psipainst, antimirror, x,y,z)
  x,y,z =psipainst:wb_to_pa_coords(x,y,z)
  local Bx,By,Bz = M.bfield_vector_cyl(psipainst.pa, x,y,z)
  Bx,By,Bz = anti(antimirror, x,y,z, Bx,By,Bz)
  Bx,By,Bz = psipainst:pa_to_wb_orient(Bx,By,Bz)
  return Bx,By,Bz
end

--[[
 Gets magnetic B-field vector (Bx,By,Bz) in gauss at point
 (x,y,z) in PA volume grid units.  Azpa is a PA containing the
 z component of magnetic vector potential.
--]]
function M.bfield_vector_2dp(Azpa, x,y,z)
  local ex,ey,ez = Azpa:field_vc(x,y,z)
  local Bx,By,Bz = -ey, ex, 0
  return Bx,By,Bz
end

--[[
 Same as bfield_vector_2dp but uses PA instance with (x,y,z) in
 workbench coordinates in mm.
--]]
function M.bfield_2dp_inst(Azpainst, antimirror, x,y,z)
  x,y,z = Azpainst:wb_to_pa_coords(x,y,z)
  local Bx,By,Bz = M.bfield_vector_2dp(Azpainst.pa, x,y,z)
  Bx,By,Bz = anti(antimirror, x,y,z, Bx,By,Bz)
  Bx,By,Bz = Azpainst:pa_to_wb_orient(Bx,By,Bz)
  return Bx,By,Bz
end

function M.make_bfield_vector(Azpainst, antimirror)
  if Azpainst.pa.symmetry_type == '2dplanar' then
    return function(x,y,z)
      return M.bfield_2dp_inst(Azpainst, antimirror, x,y,z)
    end
  elseif Azpainst.pa.symmetry_type == '2dcylindrical' then
    return function(x,y,z)
      return M.bfield_vector_cyl_inst(Azpainst, antimirror, x,y,z)
    end
  else
   error('Magnetic vector potential with 3D PA requires '..
         'using simion.experimental.field_array', 2)
  end
end

--[[
 Gets the field vector (vx,vy,vz) at point (x,y,z), both in workbench
 coordinates.
 2D cylindrical PA instance `thetainst` holds the azimuthal (theta)
 component of the field vector (v_x, v_r, v_theta) when represented
 in cylindrical coordinates.
 theta is the angle counter-clockwise from +Y axis, looking down the +X axis.
--]]
function M.azimuthal_field_inst(thetainst, x,y,z)
  x,y,z = thetainst:wb_to_pa_coords(x,y,z)
  local pa = thetainst.pa
  if not pa:inside_vc(x,y,z) then return 0,0,0 end
  local vtheta = pa:potential_vc(x,y,z)
  local ryz = math.sqrt(y^2+z^2)
  local rescale = ryz == 0 and 0 or vtheta / ryz
  local vx,vy,vz = 0, -z*rescale, y*rescale
  vx,vy,vz = thetainst:pa_to_wb_orient(vx,vy,vz)
  return vx,vy,vz
end

--[[
 Gets function `f` representing an azimuthal field given
 2D cylindrical PA instance `thetainst` containing azimuthal
 components of that field.  `f` has the form
   vx,vy,vz = f(x,y,z)
 for field (vx,vy,vz) and position (x,y,z) in workbench coordinates (mm).
--]]
function M.make_azimuthal_field(thetainst)
  return function(x,y,z)
    return M.azimuthal_field_inst(thetainst, x,y,z)
  end
end

return M
