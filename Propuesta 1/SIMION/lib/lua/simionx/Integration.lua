-- simionx.Integration.
-- This module is documented in the SIMION supplemental documentation.
-- version: 20071209
-- (c) 2007-2008 Scientific Instrument Services, Inc. (SIMION 8.0 License)

local Type = require "simionx.Type"
local Stat = require "simionx.Statistics"

local PI = math.pi
local cos = math.cos
local sin = math.sin
local abs = math.abs
local sqrt = math.sqrt
local acos = math.acos
local min = math.min
local random = math.random
local time = os.time
local yield = coroutine.yield
local make_halton = Stat.make_halton

local M = {}

local function line1d_distribution(x1, x2)
  return function()
    local halton2 = make_halton(2)
    return function()
      local a = halton2()
      local x = (x2-x1)*a+x1
      return x
    end
  end
end
local function line2d_distribution(x1,y1, x2,y2)
  return function()
    local halton2 = make_halton(2)
    return function()
      local a = halton2()
      local x,y = (x2-x1)*a+x1, (y2-y1)*a+y1
      return x,y
    end
  end
end
local function line3d_distribution(x1,y1,z1, x2,y2,z2)
  return function()
    local halton2 = make_halton(2)
    return function()
      local a = halton2()
      local x,y,z = (x2-x1)*a+x1, (y2-y1)*a+y1, (z2-z1)*a+z1
      return x,y,z
    end
  end
end
      -- slightly increased accuracy if single halton sequence is terminated
      -- on end of each halton cycle
      -- local count = 0
      -- local next_start = 2
      -- count = count + 1
      -- local extra.can_terminate
      -- if count == next_start + 1 then
      --   next_start = next_start * 2
      --   extra.can_terminate = true
      -- else
      --   extra.can_terminate = false
      -- end

local box1d_distribution = line1d_distribution
local function box2d_distribution(x1,y1, x2,y2)
  -- swap for correct order
  if x2 < x1 then x1, x2 = x2, x1 end
  if y2 < y1 then y1, y2 = y2, y1 end

  local dx = x2 - x1
  local dy = y2 - y1

  local area_sum = dx + dy
  local area_frac = dx / (area_sum * 2)

  local xmul = area_sum * 2
  local ymul = area_sum * 2

  return function()
    local halton2 = make_halton(2)
    return function()
      local a = halton2()
      local x,y, ux,uy
      if a < 0.5 then
        if a < area_frac then
          x,y = x1 + a * xmul, y1
          ux,uy = 0, -1
        else
          x,y = x1, y1 + (a - area_frac) * ymul
          ux,uy = -1, 0                
        end
      else
        local a = a - 0.5
        if a < area_frac then
          x,y = x1 + a * xmul, y2
          ux,uy = 0, 1
        else
          x,y = x2, y1 + (a - area_frac) * ymul
          ux,uy = 1, 0               
        end
      end
      return x,y, ux,uy
    end
  end
end
local function box3d_distribution(x1,y1,z1, x2,y2,z2)
  return function()
    -- swap for correct order
    if x2 < x1 then x1, x2 = x2, x1 end
    if y2 < y1 then y1, y2 = y2, y1 end
    if z2 < z1 then z1, z2 = z2, z1 end

    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1

    local areax = dy*dz
    local areay = dx*dz
    local areaz = dx*dy
    local area_sum = areax + areay + areaz

    local halton2 = make_halton(2)
    local halton3 = make_halton(3)
    local halton5 = make_halton(5)

    return function()
      local a = halton2()
      local dir = a > 0.5 and 1 or -1
      a = a * 2
      if a >= 1 then a = a - 1 end
      local x, y, z, ux, uy, uz
      if a < areax/area_sum then
        x = (dir > 0) and x2 or x1
        y = halton3() * dy  + y1
        z = halton5() * dz  + z1
        ux,uy,uz = dir,0,0
      elseif a < (areax + areay)/area_sum then
        x = halton3() * dx  + x1
        y = (dir > 0) and y2 or y1
        z = halton5() * dz + z1
        ux,uy,uz = 0,dir,0
      else
        x = halton3() * dx + x1
        y = halton5() * dy + y1
        z = (dir > 0) and z2 or z1
        ux,uy,uz = 0,0,dir
      end
      return x,y,z, ux,uy,uz
    end
  end
end

local box1d_filled_distribution = box1d_distribution
local function box2d_filled_distribution(x1,y1, x2,y2)
  return function()
    local dx = x2 - x1
    local dy = y2 - y1
    local halton2 = make_halton(2)
    local halton3 = make_halton(3)
    return function()
      local a = halton2()
      local b = halton3()
      local x,y = x1 + dx * a, y1 + dy * b
      return x,y
    end
  end
end
local function box3d_filled_distribution(x1,y1,z1, x2,y2,z2)
  return function()
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    local halton2 = make_halton(2)
    local halton3 = make_halton(3)
    local halton5 = make_halton(5)
    return function()
      local x,y,z = x1+dx*halton2(), y1+dy*halton3(), z1+dz*halton5()
      return x,y,z
    end
  end
end

local function sphere2d_distribution(xc,yc, r)
  return function()
    local halton2 = make_halton(2)
    return function()
      -- Generate random point and get unit normal vector
      local theta = halton2() * 2 * PI
      local ux,uy = cos(theta), sin(theta)
      local x,y = xc+ux*r, yc+uy*r
      return x,y, ux,uy
    end
  end
end
local function sphere3d_distribution(xc,yc,zc, r)
  local halton2 = make_halton(2)
  local halton3 = make_halton(3)
  return function()
    return function()
      -- Generates a unit vector in a uniformly random direction.
      -- Special care is taken to ensure that each direction has equal
      -- probability.
      -- This is based on the more general uniformly random vector in
      -- a cone (but with 180 degree vertex angle)
      -- -- http://www.simion.com/info/Particle_Initial_Conditions

      -- Let phi in [0, vertex_angle] be a random angle from the vertex axis.
      -- The number of points in the cone having this phi is proportional
      -- to sin(phi), so the probability distribution for phi is
      -- f(phi) = sin(phi)/(1 - cos(vertex_angle)).
      -- t = random() is a uniform random variable in [0, 1).
      -- From the fundamental transformation law of probabilities,
      -- phi = arccos(1 - t * (1 - cos(vertex_angle)))
      local phi = acos(1 - halton2() * 2)

      -- Rotation angle is a uniform random variable in [0, 2PI).
      local theta = halton3() * 2 * PI

      -- create unit vector; then transform
      local sinp = sin(phi)
      local ux,uy,uz = cos(phi), sinp*cos(theta), sinp*sin(theta)
      local x,y,z = xc+ux*r, yc+uy*r, zc+uz*r
      return x,y,z, ux,uy,uz
    end
  end
end

local function sphere1d_filled_distribution(xc, r)
  return line1d_distribution(xc-r, xc+r)
end
local function sphere2d_filled_distribution(xc,yc, r)
  return function()
    local halton2 = make_halton(2)
    local halton3 = make_halton(3)
    return function()
      local dx,dy
      while true do
        dx,dy = 0.5 - halton2(), 0.5 - halton3()
        local r2test = dx*dx + dy*dy
        if r2test <= 0.5^2 then break end
      end
      local rd = 2*r
      local x,y = xc+rd*dx, yc+rd*dy
      return x,y
    end
  end
end
local function sphere3d_filled_distribution(xc,yc,zc, r)
  return function()
    local halton2 = make_halton(2)
    local halton3 = make_halton(3)
    local halton5 = make_halton(5)
    return function(extra)
      -- Generates a unit vector in a uniformly random direction.
      -- Special care is taken to ensure that each direction has equal
      -- probability.
      -- This is based on the more general uniformly random vector in
      -- a cone (but with 180 degree vertex angle)
      -- -- http://www.simion.com/info/Particle_Initial_Conditions

      -- Let phi in [0, vertex_angle] be a random angle from the vertex axis.
      -- The number of points in the cone having this phi is proportional
      -- to sin(phi), so the probability distribution for phi is
      -- f(phi) = sin(phi)/(1 - cos(vertex_angle)).
      -- t = random() is a uniform random variable in [0, 1).
      -- From the fundamental transformation law of probabilities,
      -- phi = arccos(1 - t * (1 - cos(vertex_angle)))
      local phi = acos(1 - halton2() * 2)

      -- Rotation angle is a uniform random variable in [0, 2PI).
      local theta = halton3() * 2 * PI

      local rn = halton5() * r

      -- create unit vector; then transform
      local sinp = sin(phi)
      local ux,uy,uz = cos(phi), sinp*cos(theta), sinp*sin(theta)
      local x,y,z = xc+ux*rn, yc+uy*rn, zc+uz*rn
      extra.dmass = rn*rn
      return x,y,z
    end
  end
end




function M.line(...)
  local points, mass
  local n = select('#', ...)
  if n == 2 then
    points = line1d_distribution(...)
    local x1, x2 = ...
    mass = sqrt((x2-x1)^2)
  elseif n == 4 then
    points = line2d_distribution(...)
    local x1,y1, x2,y2 = ...
    mass = sqrt((x2-x1)^2+(y2-y1)^2)
  elseif n == 6 then
    points = line3d_distribution(...)
    local x1,y1,z1, x2,y2,z2 = ...
    mass = sqrt((x2-x1)^2+(y2-y1)^2+(z2-z1)^2)
  else
    error('requires 2, 4, or 6 arguments', 2)
  end
  return {points = points, mass = mass}
end

function M.sphere(...)
  local points, mass
  local n = select('#', ...)
  if n == 3 then
    points = sphere2d_distribution(...)
    local x0,y0, r = ...
    mass = 2 * PI * r
  elseif n == 4 then
    points = sphere3d_distribution(...)
    local x0,y0,z0, r = ...
    mass = 4 * PI * r * r
  else
    error('requires 3 or 4 arguments', 2)
  end
  return {points = points, mass = mass}
end
function M.circle2d(...)
  if select('#', ...) ~= 3 then error('requires 3 arguments', 2) end
  return M.sphere(...)
end

function M.sphere_filled(...)
  local points, mass
  local n = select('#', ...)
  if n == 2 then
    points = sphere1d_filled_distribution(...)
    local x0, r = ...
    mass = 2 * r
  elseif n == 3 then
    points = sphere2d_filled_distribution(...)
    local x0,y0, r = ...
    mass = PI * r * r
  elseif n == 4 then
    points = sphere3d_filled_distribution(...)
    local x0,y0,z0, r = ...
    mass = (4/3) * PI * r * r * r
  else
    error('requires 2, 3, or 4 arguments', 2)
  end
  return {points = points, mass = mass}
end
function M.circle2d_filled(...)
  if select('#', ...) ~= 3 then error('requires 3 arguments', 2) end
  return M.sphere_filled(...)
end


function M.box(...)
  local points, mass
  local n = select('#', ...)
  if n == 4 then
    points = box2d_distribution(...)
    local x1,y1, x2,y2 = ...
    local dx,dy = abs(x2 - x1), abs(y2 - y1)
    mass = 2 * (dx + dy)
  elseif n == 6 then
    points = box3d_distribution(...)
    local x1,y1,z1, x2,y2,z2 = ...
    local dx,dy,dz = abs(x2 - x1), abs(y2 - y1), abs(z2 - z1)
    mass = 2 * (dy * dz + dx * dz + dx * dy)
  else
    error('requires 4 or 6 arguments', 2)
  end
  return {points = points, mass = mass}
end

function M.box_filled(...)
  local points, mass
  local n = select('#', ...)
  if n == 2 then
    points = box1d_filled_distribution(...)
    local x1, x2 = ...
    local dx = abs(x2 - x1)
    mass = dx
  elseif n == 4 then
    points = box2d_filled_distribution(...)
    local x1,y1, x2,y2 = ...;
    local dx,dy = abs(x2 - x1), abs(y2 - y1)
    mass = dx * dy
  elseif n == 6 then
    points = box3d_filled_distribution(...)
    local x1,y1,z1, x2,y2,z2 = ...
    local dx,dy,dz = abs(x2 - x1), abs(y2 - y1), abs(z2 - z1)
    mass = dx * dy * dz
  else
    error('requires 2, 4, or 6 arguments', 2)
  end
  return {points = points, mass = mass}
end

local sig
local function montecarlo_integrate(t)
  sig = sig or Type {
    func           = Type['function'],
    shape          = Type.table,
    min_iterations = Type.number + Type['nil'],
    rel_err        = Type.number + Type['nil'],
    abs_err        = Type.number + Type['nil']
  }; sig:check(t)
  local func           = t.func
  local shape          = t.shape
  local min_iterations = t.min_iterations or 100
  local rel_err        = t.rel_err        or 0.001
  local abs_err        = t.abs_err        or 0

  local mass = shape.mass
  local point = shape.points()

  -- Computes a moving average similar to an n-value weighted moving
  -- average (WMA) but with variable n equal to the iteration number.
  --   WMA_n = (n*x_n + (n-1)*x_{n-1} + ... + 1*x_1) / (n + (n-1) + ... + 1)
  --   WMA_n = (n*x_n + (n-1)*x_{n-1} + ... + 1*x_1) / (n*(n+1)/2)
  --   WMA_n = ((n-1)*WMA_{n-1} + 2*x_n) / (n + 1)
  -- This gives representation predominantly to the last n/2 values.
  local function wma_averager()
    local n=0
    local wma
    return function(x)
      n = n + 1
      if n == 1 then
        wma = x
      else
        wma = ((n-1)*wma + 2*x) / (n+1)
      end
      return wma
    end
  end

  local extra = {}
  extra.dmass = 1
  extra.can_terminate = true

  local averager1 = wma_averager()
  local averager2 = wma_averager()
  local sum = 0
  local count = 0
  local totalmass = 0
  local next_report_count = 1
  local last_report_time = time() - 1
  while true do
    local ave_ave,ave_ave2
    repeat
      local val = func(point(extra))
      local dmass = extra.dmass
      sum       = sum       + dmass * val
      totalmass = totalmass + dmass
      count     = count     + 1
      local ave = sum/totalmass

      -- The moving mean and mean square of ave is used later to estimate the
      -- moving standard deviation of ave as a rough estimation of error in ave.
      -- Error is generally expected to be of order between O(n^{-1/2})
      -- (pure Monte-Carlo) and O(n^-1) (equally spaced test points) for
      -- iteration number n.  In either case, error is very roughly constant
      -- over the last n/2 values, which fits the condition in wma_averager.
      ave_ave  = averager1(ave)
      ave_ave2 = averager2(ave*ave)
    until extra.can_terminate

    local current_time = time()

    local is_report = false
    if count >= next_report_count then
      next_report_count = next_report_count * 2  -- exponential increase
      is_report = true
    elseif current_time >= last_report_time + 1 then
      is_report = true
    end

    if is_report then
      last_report_time = current_time

      -- Average value of integrand.
      local ave = sum/totalmass
      -- Estimated error in ave from moving standard deviation of ave.
      -- Note: abs prevents small negative values upon small numerical error
      local ave_err = sqrt(abs(ave_ave2 - ave_ave*ave_ave))

      local result     = mass * ave
      local result_err = mass * ave_err

      local fe = result_err / (result == 0 and math.huge or abs(result))
  
      local is_end = extra.can_terminate == true and
                     count >= min_iterations and
                     fe < rel_err or result_err < abs_err

      yield(result, result_err, count, is_end)
    end
  end
end

function M.montecarlo_integrate(t)
  local co = montecarlo_integrate
  if t then co = coroutine.wrap(co); co(t) end
  return co
end

return M
