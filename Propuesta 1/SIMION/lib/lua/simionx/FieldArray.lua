--[[
 simionx.FieldArray
 This module is documented in the SIMION supplemental documentation.
 version: 20120410
 (c) 2007-2012 Scientific Instrument Services, Inc. (SIMION 8.0 License)
--]]

local Sup = require "simionx.Support"
local Type = require "simionx.Type"

local elevation_rotate = simion.elevation_rotate
local azimuth_rotate   = simion.azimuth_rotate
local sin   = math.sin
local cos   = math.cos
local floor = math.floor
local sqrt  = math.sqrt
local abs   = math.abs

local isx = {x = true, xy = true, xz = true, xyz = true}
local isy = {y = true, xy = true, yz = true, xyz = true}
local isz = {z = true, xz = true, yz = true, xyz = true}

local M = {}; M.__index = M

local T_symmetry = Type(
  function(v) return v == "cylindrical" or v == "planar" end,
  [["cylindrical" or "planar"]]
)

local T_potential_type = Type(
  function(v) return v == "electric" or v == "magnetic" end,
  [["electric" or "magnetic"]]
)

local mirrors = {
  [""] = true, x = true, y = true, z = true,
  xy = true, xz = true, yz = true, xyz = true
}
local T_mirror = Type (
  function(v) return mirrors[v] end,
  [["", "x", "y", "z", "xy", "xz", "yz", or "xyz"]]
)

local tmp_header
local function field_array_wrapper(...)
  tmp_header = M (...)
end


-- Transform system coordinates (mm) to array coordinates (gu).
-- [private]
function M._system_to_array_coords(header, x, y, z)
  -- Translate to array coordinates.
  x = x - header.x
  y = y - header.y
  z = z - header.z
  x = x / (header.scale * header.dx_mm)
  y = y / (header.scale * header.dy_mm)
  z = z / (header.scale * header.dz_mm)
  if header.az ~= 0 then
    x, y, z = azimuth_rotate(-header.az, x, y, z)
  end
  if header.el ~= 0 then
    x, y, z = elevation_rotate(-header.el, x, y, z)
  end
  if header.rt ~= 0 then
    -- Note: there's no built-in function for rt rotation.
    local t = -header.rt * math.pi / 180
    local cosa, sina = cos(t), sin(t)
    if abs(cosa) < 1e-16 then cosa = 0 end
    if abs(sina) < 1e-16 then sina = 0 end
    y, z = y * cosa - z * sina, y * sina + z * cosa
  end
  local cyl_angle, z_depth
  if header.symmetry == "cylindrical" then
    cyl_angle = math.atan2(z, y)
    --print('c', cos(cyl_angle), cos(math.pi*0.5))
    y = sqrt(y*y + z*z)
    z = 0
  else
    if header.nz == 1 then
      z_depth = z
      z = 0
    end
  end
  local mirrorx, mirrory, mirrorz = false, false, false
  if header.mirror ~= "" then
    if x < 0 and isx[header.mirror] then
      x = -x; mirrorz = true
    end
    if y < 0 and isy[header.mirror] then
      y = -y; mirrory = true
    end
    if z < 0 and isz[header.mirror] then
      z = -z; mirrorz = true
    end
  end
  return x, y, z, cyl_angle, z_depth, mirrorx, mirrory, mirrorz
end

-- Transforms array coordinates to system coordinates.
-- Note: Applies rotation only (not translation or scaling).
-- [private]
function M._array_to_system_coords_rotate(
  header, bx, by, bz, cyl_angle, mirrorx, mirrory, mirrorz
)
    if mirrorx then bx = -bx end
    if mirrory then by = -by end
    if mirrorz then bz = -bz end
    if header.symmetry == "cylindrical" then
      local cosa, sina = cos(cyl_angle), sin(cyl_angle)
      if abs(cosa) < 1e-16 then cosa = 0 end
      if abs(sina) < 1e-16 then sina = 0 end
      by, bz = by * cosa - bz * sina, by * sina + bz * cosa
    end
    if header.rt ~= 0 then
      -- Note: there's no built-in function for rt rotation.
      local t = header.rt * math.pi * (1 / 180)
      local cosa, sina = cos(t), sin(t)
      if abs(cosa) < 1e-16 then cosa = 0 end
      if abs(sina) < 1e-16 then sina = 0 end
      by, bz = by * cosa - bz * sina,
               by * sina + bz * cosa
    end
    if header.el ~= 0 then
      bx, by, bz = elevation_rotate(header.el, bx, by, bz)
    end
    if header.az ~= 0 then
      bx, by, bz = azimuth_rotate(header.az, bx, by, bz)
    end
    return bx,by,bz
end

-- Set field vector at given integer grid point
-- (in array coordinates).
function M:seti(x,y,z, bx, by, bz)
  local h = self
  local d = self.data
  local base = ((z * h.ny + y) * h.nx + x) * 3
  d[base + 1] = bx
  d[base + 2] = by
  d[base + 3] = bz
end

-- Get field vector at given integer grid point
-- (in array coordinates).
function M:geti(xi, yi, zi)
  local h = self; local d = self.data
  local base = ((zi * h.ny + yi) * h.nx + xi) * 3
  return d[base + 1], d[base + 2], d[base + 3]
end

function M:get(x, y, z)
  local header = self

  local cyl_angle, z_depth, mirrorx, mirrory, mirrorz
  x, y, z, cyl_angle, z_depth, mirrorx, mirrory, mirrorz
    = M._system_to_array_coords(header, x,y,z)

  -- Get integer and fractional parts of grid positions.
  local xint = floor(x)
  local xrfrac = x - xint
  local xlfrac = 1 - xrfrac
  local yint = floor(y)
  local yrfrac = y - yint
  local ylfrac = 1 - yrfrac
  local zint = floor(z)
  local zrfrac = z - zint
  local zlfrac = 1 - zrfrac

  local nx = header.nx
  local ny = header.ny
  local nz = header.nz

  local bx, by, bz

  -- If position inside array.
  if xint >= 0 and (xint < nx-1 or xint == nx-1 and xrfrac == 0) and
     yint >= 0 and (yint < ny-1 or yint == ny-1 and yrfrac == 0) and
     zint >= 0 and (zint < nz-1 or zint == nz-1 and zrfrac == 0)
  then
    local data = self.data

    -- offset to lower-left (LL) corner point
    local idx = ((zint * ny + yint) * nx + xint) * 3
    local lln_bx = idx + 1        -- index of LL corner of bx
    local lln_by = idx + 2        -- index of LL corner of by
    local lln_bz = idx + 3        -- index of LL corner of bz

    -- First do 2D calculation.

    local AX = (xint == nx-1 and 0 or 3)
    local AY = (yint == ny-1 and 0 or nx*3)
    local RL = AX
    local LR = AY
    local RR = AX + AY

    -- calculate ion's B_x field by linear interpolation
    bx =
      ( data[lln_bx]      * xlfrac +
        data[lln_bx + RL] * xrfrac    ) * ylfrac +
      ( data[lln_bx + LR] * xlfrac +
        data[lln_bx + RR] * xrfrac    ) * yrfrac

    -- calculate ion's B_y field by linear interpolation
    by =
      ( data[lln_by]      * xlfrac +
        data[lln_by + RL] * xrfrac    ) * ylfrac +
      ( data[lln_by + LR] * xlfrac +
        data[lln_by + RR] * xrfrac    ) * yrfrac

    -- calculate ion's B_z field by linear interpolation
    bz =
      ( data[lln_bz]      * xlfrac +
        data[lln_bz + RL] * xrfrac    ) * ylfrac +
      ( data[lln_bz + LR] * xlfrac +
        data[lln_bz + RR] * xrfrac    ) * yrfrac
  
    -- Optionally do 3D calculation (reusing 2D result in part)
    if zrfrac ~= 0 then
      local skip = ny * nx * 3
      lln_bx = lln_bx + skip
      lln_by = lln_by + skip
      lln_bz = lln_bz + skip
  
      -- calculate ion's B_x field by linear interpolation
      local bx2 =
        ( data[lln_bx]      * xlfrac +
          data[lln_bx + RL] * xrfrac    ) * ylfrac +
        ( data[lln_bx + LR] * xlfrac +
          data[lln_bx + RR] * xrfrac    ) * yrfrac
  
      -- calculate ion's B_y field by linear interpolation
      local by2 =
        ( data[lln_by]      * xlfrac +
          data[lln_by + RL] * xrfrac    ) * ylfrac +
        ( data[lln_by + LR] * xlfrac +
          data[lln_by + RR] * xrfrac    ) * yrfrac
  
      -- calculate ion's B_z field by linear interpolation
      local bz2 =
        ( data[lln_bz]      * xlfrac +
          data[lln_bz + RL] * xrfrac    ) * ylfrac +
        ( data[lln_bz + LR] * xlfrac +
          data[lln_bz + RR] * xrfrac    ) * yrfrac

      bx = bx * zlfrac + bx2 * zrfrac
      by = by * zlfrac + by2 * zrfrac
      bz = bz * zlfrac + bz2 * zrfrac
    end

    bx, by, bz = M._array_to_system_coords_rotate(
      self, bx,by,bz, cyl_angle, mirrorx, mirrory, mirrorz)


  else  -- outside array (zero field)
    bx, by, bz = 0, 0, 0
  end

  return bx, by, bz
end

function M:write(dest)
  local need_close = false
  if type(dest) == "string" then
    dest = assert(io.open(dest, "w"))
    need_close = true
  end

  dest:write(Sup.subst(
    [[fieldx,fieldy,fieldz,"field_array{nx=$(nx),ny=$(ny),nz=$(nz),symmetry='$(symmetry)',mirror='$(mirror)',dx_mm=$(dx_mm),dy_mm=$(dy_mm),dz_mm=$(dz_mm),potential_type='$(potential_type)',rt=$(rt),el=$(el),az=$(az),scale=$(scale),x=$(x),y=$(y),z=$(z)}"]]
  , self), "\n")

  for i,v in ipairs(self.data) do
    dest:write(v, (i % 3) == 0 and "\n" or ", ")
  end

  if need_close then dest:close() end
end

do
  -- Helper function to read field from function func.
  -- func is a function that takes x,y,z coordinates and
  -- return the field components at that location
  -- "func : x,y,z --> bx,by,bz"
  -- Example:
    --   function(x,y,z) return 10,0,0 end
  local function read_from_function(self, func)
    local h = self
    local d = self.data

    local n = 0
    for zi=0,h.nz-1 do
    for yi=0,h.ny-1 do
    for xi=0,h.nx-1 do
      -- Transform array coordinates to workbench coordinates.
      local x, y, z = xi, yi, zi
      if h.rt ~= 0 then
        -- Since there's no built-in function for rt rotation,
        -- express it manually
        local t = h.rt * math.pi / 180
        local cosa, sina = cos(t), sin(t)
        if abs(cosa) < 1e-16 then cosa = 0 end
        if abs(sina) < 1e-16 then sina = 0 end
        y, z = y * cosa - z * sina, y * sina + z * cosa
      end
      if h.el ~= 0 then
        x, y, z = elevation_rotate(h.el, x, y, z)
      end
      if h.az ~= 0 then
        x, y, z = azimuth_rotate(h.az, x, y, z)
      end
      x = x * (h.scale * h.dx_mm)
      y = y * (h.scale * h.dy_mm)
      z = z * (h.scale * h.dz_mm)
      x = x + h.x
      y = y + h.y
      z = z + h.z
  
      -- Compute and store field at point.
      d[n+1], d[n+2], d[n+3] = func(x,y,z)
  
      n = n + 3
    end end end
  end
function M:read(src)
  if type(src) == "function" then
    read_from_function(self, src)
    return
  end
 
  local need_close = false
  if type(src) == "string" then
    src = assert(io.open(src))
    need_close = true
  end

  -- Environment for Lua code on first line.
  local env = {field_array = field_array_wrapper}

  -- Load header from first line.
  tmp_header = nil
  local line1 = src:read("*l")
  line1 = line1:gsub('^%s*"?%s*fieldx%s*"?%s*,?%s*', '')
  line1 = line1:gsub('^%s*"?%s*fieldy%s*"?%s*,?%s*', '')
  line1 = line1:gsub('^%s*"?%s*fieldz%s*"?%s*,?%s*', '')
  line1 = line1:gsub('^%s*"', '')
  line1 = line1:gsub('%s*"$', '')
  local func = assert(loadstring(line1))
  setfenv(func, env)
  func()
  if tmp_header == nil then
    error("no Header{...} line in file " .. src, 2)
  end
  local header = tmp_header
  tmp_header = nil

  -- Read magnetic field vectors (Bx, By, Bz) as tripplets of numbers.
  local data = {}
  while true do
    local v = src:read("*n")
    if not v then
      local v2 = src:read(1) -- try to skip one character (e.g. comma)
      if not v2 then break end -- end of file
    end
    data[#data + 1] = v
  end

  if need_close then src:close() end

  local npoints = header.nx * header.ny * header.nz
  local nvalues = npoints * 3
  if #data ~= nvalues then
    error(string.format("Expected %d values (%d points) in file (found %d).",
          nvalues, npoints, #data))
  end

  for k,v in pairs(header) do
    self[k] = v
  end
  self.data = data
end end

function M:convert_to_pas(basename, save)
  local xpa = simion.pas:open()
  local ypa = simion.pas:open()
  local zpa = simion.pas:open()
  xpa:size(self.nx, self.ny, self.nz)
  ypa:size(xpa:size())
  zpa:size(xpa:size())
  xpa.symmetry = (self.symmetry == 'cylindrical' and '2dcylindrical' or
                  self.nz == 1 and '2dplanar' or '3dplanar')
  ypa.symmetry = xpa.symmetry
  zpa.symmetry = xpa.symmetry
  xpa.dx_mm = self.dx_mm; xpa.dy_mm = self.dy_mm; xpa.dz_mm = self.dz_mm
  ypa.dx_mm = self.dx_mm; ypa.dy_mm = self.dy_mm; ypa.dz_mm = self.dz_mm
  zpa.dx_mm = self.dx_mm; zpa.dy_mm = self.dy_mm; zpa.dz_mm = self.dz_mm
  xpa.refinable = false
  ypa.refinable = false
  zpa.refinable = false
  xpa.potential_type = self.potential_type
  ypa.potential_type = self.potential_type
  zpa.potential_type = self.potential_type
  for x,y,z in xpa:points() do
    local ex,ey,ez = self:geti(x,y,z)
    xpa:potential(x,y,z, ex)
    ypa:potential(x,y,z, ey)
    zpa:potential(x,y,z, ez)
  end
  basename = (basename or '')
  xpa.filename = basename.."x.pa"
  ypa.filename = basename.."y.pa"
  zpa.filename = basename.."z.pa"
  if save then
    xpa:save(); ypa:save(); zpa:save()
  end
  return xpa, ypa, zpa
end

local construct; do
  local argdefaults = {
    nx = 1, ny = 1, nz = 1,
    symmetry = "planar",
    mirror = "",
    dx_mm = 1, dy_mm = 1, dz_mm = 1,
    potential_type = 'electric',
    rt = 0, el = 0, az = 0,
    scale = 1,
    x = 0, y = 0, z = 0
  }
  argdefaults.__index = argdefaults
  local argtypes = Type {
    nx = Type.positive_integer,
    ny = Type.positive_integer,
    nz = Type.positive_integer,
    symmetry = T_symmetry,
    mirror = T_mirror,
    dx_mm = Type.positive_number,
    dy_mm = Type.positive_number,
    dz_mm = Type.positive_number,
    potential_type = T_potential_type,
    rt = Type.number, -- degrees
    el = Type.number, -- degrees
    az = Type.number, -- degrees
    scale = Type.positive_number,
    x = Type.number,
    y = Type.number,
    z = Type.number
  }
function construct(class, t)
  local filename
  if type(t) == "string" then
    filename = t
    t = {}
  end
  local mirror = t.mirror
  setmetatable(t, argdefaults)
  argtypes:check(t, 2)
  if t.symmetry == "cylindrical" and t.nz ~= 1 then
    error("cylindrical array requires nz = 1", 2)
  end
  mirror = (t.symmetry == "cylindrical" and mirror == nil and "y") or t.mirror
  if (t.symmetry == "cylindrical" or t.nz == 1) and isz[mirror] then
    error("2D arrays allows only x and y mirroring.", 2)
  end
 
  local self = {
    nx = t.nx,
    ny = t.ny,
    nz = t.nz,
    symmetry = t.symmetry,
    mirror = mirror,
    dx_mm = t.dx_mm,
    dy_mm = t.dy_mm,
    dz_mm = t.dz_mm,
    potential_type = t.potential_type,
    rt = t.rt,
    el = t.el,
    az = t.az,
    scale = t.scale,
    x = t.x,
    y = t.y,
    z = t.z,
    data = {}
  }
  setmetatable(self, M)

  if false then --optionally pre-allocate
    local data = self.data
    for n = 1, self.nx * self.ny * self.nz do
      self[n] = false
    end
  end

  if filename ~= nil then
    self:read(filename)
  end
  return self
end end
setmetatable(M, { __call = construct})

M.__call = M.get

return M
