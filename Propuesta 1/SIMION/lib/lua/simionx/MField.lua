-- simionx.MField
-- This module is documented in the SIMION supplemental documentation.
-- version: 20110826
-- (c) 2007-2011 Scientific Instrument Services, Inc. (SIMION 8.0/8.1 License)

local Sup = require "simionx.Support"
local Type = require "simionx.Type"
--local SF = require "simionx.SpecialFunctions"

-- Making these local speeds it up ~5-20%.
local sin  = math.sin
local cos  = math.cos
local sqrt = math.sqrt
local pi   = math.pi
local abs  = math.abs
local min  = math.min
--local elliptic_ke = SF.elliptic_ke
--local rect3d_to_polar3d = simion.rect3d_to_polar3d
--local azimuth_rotate    = simion.azimuth_rotate
--local elevation_rotate  = simion.elevation_rotate

local M = Sup.module()

-- faster C implementations
local loc = M
simion._load_implementation("simionx.MField", loc)
local solenoid_coil_impl  = assert(loc.solenoid_coil_impl)
local hoop_impl           = assert(loc.hoop_impl)
local line_segment_impl   = assert(loc.line_segment_impl)
local solenoid_hoops_impl = assert(loc.solenoid_hoops_impl)

-- return vector cross product of A x B.
local function vcross(ax, ay, az, bx, by, bz)
  return ay*bz - az*by,
         az*bx - ax*bz,
         ax*by - ay*bx
end

-- return vector norm
local function vnormalize(ax, ay, az)
  local s = 1 / sqrt(ax*ax + ay*ay + az*az)
  return ax * s, ay * s, az * s
end

-- scales vector by scalar
local function vscale(k, ax,ay,az)
  return k*ax, k*ay, k*az
end

M.vector = Type.vector

-- Make orthogonal right hand coordinate system with
-- unit vectors <u>, <v>, and <w>.
local function make_coords(wx,wy,wz)
  -- Pick arbitrary vector <t> not parallel to <w>.
  local tx, ty, tz = 0, 0, 0
  local ax, ay, az = abs(wx), abs(wy), abs(wz)
  local amin = min(ax, ay, az)
  if     amin == ax then tx = 1
  elseif amin == ay then ty = 1
  else                   tz = 1 end

  local vx, vy, vz = vnormalize(vcross(tx,ty,tz, wx,wy,wz))
  local ux, uy, uz = vnormalize(vcross(vx,vy,vz, wx,wy,wz))
  return ux,uy,uz, vx,vy,vz
end

-- Whether can draw line (requires SIMION >= 8.1.0)
M.can_draw = (simion.experimental.plot_line_segment ~= nil)

-- note: does nothing in SIMION < 8.1.0.
local plot_line_segment = simion.experimental.plot_line_segment or function() end


-- Return magnetic field at point p = (px, py, pz)
-- due to line segment from p1 = (p1x, p1y, p1z) to
-- p2 = (p2x, p2y, p2z) with current i.
-- function M.line_segment_impl(
--   i, p1x,p1y,p1z, p2x,p2y,p2z, px,py,pz)

-- Return magnetic field at point p = (px, py, pz)
-- due to thin air coil with current i, axis ends p1 = (p1x, p1y, p1z) and
-- p2 = (p2x, p2y, p2z), radius r, and nturns turns.
-- Current is clockwise from p1 to p2.
-- divs_per_turn is the number of subdivisions around the circle to
-- use when doing the calculation (calculation approaches perfect
-- accuraty but takes longer as this approaches infinity)--can be omitted
-- to use default.
-- function M.solenoid_coil_impl(
--   i, p1x,p1y,p1z, p2x,p2y,p2z, r, nturns, divs_per_turn, px, py, pz
-- )

-- Return magnetic field at point p = (px, py, pz)
-- due to thin air coil with current i, axis ends p1 = (p1x, p1y, p1z) and
-- p2 = (p2x, p2y, p2z), radius r, and nturns turns.
-- Current is clockwise from p1 to p2.
-- divs_per_turn is the number of subdivisions around the circle to
-- use when doing the calculation (calculation approaches perfect
-- accuraty but takes longer as this approaches infinity)--can be omitted
-- to use default.
-- function M.solenoid_hoops_impl(
--   i, p1x,p1y,p1z, p2x,p2y,p2z, r, nturns, px, py, pz
-- )


local function make_class()
  local c = {}; c.__index = c
  return c
end

local line_segment_type = make_class(); do
  function line_segment_type.__call(t, x, y, z)
    local p1 = t.first
    local p2 = t.last
    return line_segment_impl(
      t.current,
      p1[1],p1[2],p1[3], p2[1],p2[2],p2[3],
      x, y, z
    )
  end
  function line_segment_type:draw()
    plot_line_segment(
      self.first[1], self.first[2], self.first[3],
      self.last[1],  self.last[2],  self.last[3])
  end

  local argtype = Type {
    current = Type.number,
    first = Type.number_vector,
    last = Type.number_vector
  }
  function M.line_segment(t)
    argtype:check(t, 2)
    assert(not(t.first[1] == t.last[1] and
               t.first[2] == t.last[2] and
               t.first[3] == t.last[3]))

    local o = setmetatable({
      current = t.current,
      first = M.vector(t.first[1], t.first[2], t.first[3]),
      last  = M.vector(t.last[1],  t.last[2],  t.last[3])
    }, line_segment_type)
    return o
  end
end


local hoop_type = make_class(); do
  function hoop_type.__call(t, x, y, z)
    local c = t.center
    local d = t.normal

    local p1x, p1y, p1z = c[1] - d[1], c[2] - d[2], c[3] - d[3]
    local p2x, p2y, p2z = c[1] + d[1], c[2] + d[2], c[3] + d[3]

    return solenoid_hoops_impl(
      t.current,
      p1x,p1y,p1z, p2x,p2y,p2z,
      t.radius, 1,
      x, y, z
    )
  end
  function hoop_type:draw()
    local cx,cy,cz = self.center[1], self.center[2], self.center[3]
    local wx,wy,wz = self.normal[1], self.normal[2], self.normal[3]
    local ux,uy,uz, vx,vy,vz = make_coords(wx,wy,wz)
    ux,uy,uz = vscale(self.radius, ux,uy,uz)
    vx,vy,vz = vscale(self.radius, vx,vy,vz)
    local x1,y1,z1
    for i=0,360,10 do
      local theta2 = i * math.pi/180
      local cos2,sin2 = cos(theta2),sin(theta2)
      local x2 = cx+ux*cos2+vx*sin2
      local y2 = cy+uy*cos2+vy*sin2
      local z2 = cz+uz*cos2+vz*sin2
      if i ~= 0 then
        plot_line_segment(x1,y1,z1, x2,y2,z2)
      end
      x1,y1,z1 = x2,y2,z2 -- advance
    end
  end

  local argtype = Type {
    current = Type.number,
    center = Type.number_vector,
    normal = Type.nonzero_number_vector,
    radius = Type.positive_number
  }
  function M.hoop(t)
    argtype:check(t, 2)
    local o = setmetatable({
      current = t.current,
      center  = M.vector(t.center[1], t.center[2], t.center[3]),
      normal  = M.vector(t.normal[1], t.normal[2], t.normal[3]),
      radius  = t.radius,
    }, hoop_type)
    return o
  end
end

local solenoid_hoops_type = make_class(); do
  function solenoid_hoops_type.__call(t, x, y, z)
    local p1 = t.first
    local p2 = t.last
    return solenoid_hoops_impl(
      t.current,
      p1[1],p1[2],p1[3], p2[1],p2[2],p2[3],
      t.radius, t.nturns,
      x, y, z
    )
  end
  function solenoid_hoops_type.draw(t)
    local dx = (t.last[1]-t.first[1])/t.nturns
    local dy = (t.last[2]-t.first[2])/t.nturns
    local dz = (t.last[3]-t.first[3])/t.nturns
    local normal = {dx,dy,dz}
    local tt = {radius=t.radius, normal=normal, center={}}
    local fx,fy,fz = t.first[1]-0.5*dx, t.first[2]-0.5*dy, t.first[3]-0.5*dz
    for i=1,t.nturns do
      tt.center[1],tt.center[2],tt.center[3] = fx+i*dx, fy+i*dy, fz+i*dz
      hoop_type.draw(tt)
    end
  end

  local argtype = Type {
    current = Type.number,
    first = Type.number_vector,
    last = Type.number_vector,
    radius = Type.nonnegative_number,
    nturns = Type.nonnegative_integer
  }
  function M.solenoid_hoops(t)
    argtype:check(t, 2)

    local o = setmetatable({
      current = t.current,
      first = M.vector(t.first[1], t.first[2], t.first[3]),
      last  = M.vector(t.last[1],  t.last[2],  t.last[3]),
      radius = t.radius,
      nturns = t.nturns
    }, solenoid_hoops_type)
    return o
  end
end

local solenoid_coil_type = make_class(); do
  function solenoid_coil_type.__call(t, x, y, z)
    local p1 = t.first
    local p2 = t.last
    return solenoid_coil_impl(
      t.current,
      p1[1],p1[2],p1[3], p2[1],p2[2],p2[3],
      t.radius, t.nturns,
      t.divs_per_turn,
      x, y, z
    )
  end
  function solenoid_coil_type.draw(t)
    local p1x,p1y,p1z = t.first[1], t.first[2], t.first[3]
    local p2x,p2y,p2z = t.last[1], t.last[2], t.last[3]
   
    -- Inscribed polygon correction (Snow).
    -- Increase polygon radius by 2/3 of the sagitta.
    -- This actually doesn't have much effect.
    local f = 2*math.pi/t.divs_per_turn
    r = t.radius*(1 + f*f*(1/12))
  
    local wx,wy,wz = p2x-p1x, p2y-p1y, p2z-p1z
    local ux,uy,uz, vx,vy,vz = make_coords(wx,wy,wz)
    ux,uy,uz = vscale(r, ux,uy,uz)
    vx,vy,vz = vscale(r, vx,vy,vz)
    local N = t.nturns * t.divs_per_turn
    for i=0,N do
      local t2 = i / N
      local angle2 = 2 * pi * t.nturns * t2
      local cos2 = cos(angle2)
      local sin2 = sin(angle2)
      local x2 = p1x + wx * t2 + cos2 * ux + sin2 * vx
      local y2 = p1y + wy * t2 + cos2 * uy + sin2 * vy
      local z2 = p1z + wz * t2 + cos2 * uz + sin2 * vz
      if i ~= 0 then
        plot_line_segment(x1,y1,z1, x2,y2,z2)
      end
      x1,y1,z1 = x2,y2,z2 -- advance
    end
  end

  local argtype = Type {
    current = Type.number,
    first   = Type.number_vector,
    last    = Type.number_vector,
    radius  = Type.nonnegative_number,
    nturns  = Type.nonnegative_integer,
    divs_per_turn = Type.positive_integer
  }
  local argdefs = {
    divs_per_turn = 100
  }
  argdefs.__index = argdefs
  function M.solenoid_coil(t)
    setmetatable(t, argdefs)
    argtype:check(t, 2)
    -- Axis required to define orientation.
    assert(t.first[1] ~= t.last[1] or t.first[2] ~= t.last[2] or t.first[3] ~= t.last[3])
    local o = setmetatable({
      current = t.current,
      first   = M.vector(t.first[1], t.first[2], t.first[3]),
      last    = M.vector(t.last[1],  t.last[2],  t.last[3]),
      radius  = t.radius,
      nturns  = t.nturns,
      divs_per_turn = t.divs_per_turn,
    }, solenoid_coil_type)
    return o
  end
end

local uniform_field_type = make_class(); do
  function uniform_field_type.__call(t, x_, y_, z_)
    return t[1], t[2], t[3]
  end
  function uniform_field_type:draw()
    -- nothing
  end

  function M.uniform_field(x,y,z)
    assert(Type.is_number(x))
    assert(Type.is_number(y))
    assert(Type.is_number(z))

    local o = setmetatable({x,y,z}, uniform_field_type)
    return o
  end
end

local combined_field_type = make_class(); do
  function combined_field_type:__call(x, y, z)
    local fx, fy, fz = 0,0,0
    for n=1,#self do
      local fx2, fy2, fz2 = self[n](x, y, z)
      fx = fx + fx2
      fy = fy + fy2
      fz = fz + fz2
    end
    return fx, fy, fz
  end
  function combined_field_type:draw()
    for i=1,#self do
      self[i]:draw()
    end
  end

  function M.combined_field(t)
    local self = setmetatable({}, combined_field_type)
    for n=1,#t do self[n] = t[n] end
    return self
  end
end

return M
