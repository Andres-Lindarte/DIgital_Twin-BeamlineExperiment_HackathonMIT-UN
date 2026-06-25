-- simionx.Statistics
-- This module is documented in the SIMION supplemental documentation.
-- version: 20130222
-- (c) 2007-2013 Scientific Instrument Services, Inc. (SIMION 8/8.1 License)

local Sup = require "simionx.Support"

local Type = require "simionx.Type"
local rand = simion.rand
local ln = math.log
local sqrt = math.sqrt

local M = Sup.module()

function M.gaussian_rand()
  -- Using the Box-Muller algorithm.
  local s = 1
  local v1, v2
  while s >= 1 do
    v1 = 2*rand() - 1
    v2 = 2*rand() - 1
    s = v1*v1 + v2*v2
  end
  local rand1 = v1*sqrt(-2*ln(s) / s)  -- (assume divide by zero improbable?)
  return rand1
end

function M.sphere_rand(r)
  r = r or 1
  -- Marsaglia, Ann. Math. Stat. 43,645-646 (1972) doi:10.1214/aoms/1177692644 .
  -- Knop, CACM 13,5,326 (1970) doi:10.1145/362349.362377 .
  -- Sample z and azimuthal angle (around z) each from uniform distributions.
  -- First select point (x',y') uniformly within unit circle.
  -- x'^2+y'^2 has a uniform distribution used to define z.
  -- (x',y') is uniformly distributed in azimuthal angle and is rescaled
  -- to define (x,y) such that x^2+y^2+z^2 = r^2.
  local xp,yp
  local S
  repeat
    xp = 2*rand()-1
    yp = 2*rand()-1
    S = xp*xp + yp*yp
  until S <= 1  -- rejection method
  local z = (2*S - 1)*r
  local f = 2*r*sqrt(1-S)  -- rescaling factor for x,y
  local x, y = xp*f, yp*f
  return x,y,z
end
--[[-- alternate version
function M.sphere_rand(r)
  r = r or 1
  local xp,yp,zp,S
  repeat
    xp,yp,zp = rand()-0.5, rand()-0.5, rand()-0.5
    S = xp*xp + yp*yp + zp*zp
  until S <= 0.25 and S ~= 0  -- rejection method
  local f = r/sqrt(S)
  local x,y,z = xp*f,yp*f,zp*f
  return x,y,z
end
--]]
--[[-- alternate version
local gaussian_rand = M.gaussian_rand
function M.sphere_rand(r)
  r = r or 1
  local xp,yp,zp = gaussian_rand(), gaussian_rand(), gaussian_rand()
  local S = sqrt(xp*xp+yp*yp+zp*zp)
  if S == 0 then return M.sphere_rand(r) end -- retry
  local f = r/S
  local x,y,z = xp*f,yp*f,zp*f
  return x,y,z
end
--]]

-- Helper function used by angle_rand.
-- Generates random angle in spherical cap such that
-- all surface area in the cap is uniformly weighted.
local function uniform_angle_rand(half_angle_deg)
  -- Let a in [0, half_angle] be a random angle from the half axis.
  -- The number of points in the cone having this a is proportional
  -- to sin(a), so the probability distribution for a is
  -- f(a) = sin(a)/(1 - cos(half_angle)).
  -- t = rand() is a uniform random variable in [0, 1).
  -- From the fundamental transformation law of probabilities,
  -- a = arccos(1 - t * (1 - cos(half_angle)))
  local c = (1 - math.cos(math.rad(half_angle_deg)))
  local a = math.deg(math.acos(1 - rand() * c))
  return a
end

function M.angle_rand(half_angle_deg, ux,uy,uz)
  local a_deg
  if type(half_angle_deg) == 'function' then
    a_deg = half_angle_deg()
  elseif type(half_angle_deg) == 'number' then
    if math.abs(half_angle_deg) > 180 then
      error('invalid half_angle_deg', 2)
    end
    if half_angle_deg <= 0 then
      a_deg = -half_angle_deg
    else
      a_deg = uniform_angle_rand(half_angle_deg)
    end
  else
    error('invalid half_angle_deg', 2)
  end
  local a_rad = math.rad(a_deg)
  
  -- convert axis direction to elevation and azimuth angles
  local r, az, el = rect3d_to_polar3d(ux,uy,uz)
  
  -- rotation angle is a uniform random variable in [0, 2PI).
  local rot = rand() * 2 * math.pi
 
  -- create vector, assuming cone axis on +x axis
  local x,y,z =
    r * math.cos(a_rad),
    r * math.sin(a_rad) * math.cos(rot),
    r * math.sin(a_rad) * math.sin(rot)

  -- rotate vector to axis direction
  x,y,z = elevation_rotate(el, x,y,z)
  x,y,z = azimuth_rotate  (az, x,y,z)
  return x,y,z
end

function M.array_min(t)
  assert(Type.is_number_array(t))
  local lim = t[1]
  for _,v in ipairs(t) do
    if v < lim then lim = v end
  end
  return lim
end

function M.array_max(t)
  assert(Type.is_number_array(t))
  local lim = t[1]
  for _,v in ipairs(t) do
    if v > lim then lim = v end
  end
  return lim
end

function M.array_mean(t)
  local result = 0
  local count = 0
  for _,v in ipairs(t) do
    result = result + v
    count = count + 1
  end
  return count ~= 0 and result / count or nil
end

function M.array_mean_and_variance(t)
  if #t == 0 then return nil, nil end
  if #t == 1 then return t[1], nil end

  -- West algorithm
  -- [West 1979] http://doi.acm.org/10.1145/359146.359153
  -- Numerically stable online algorithm.
  -- Defined by the recurrence relation:
  --   mean_1 = x_1, T_1 = 0
  --   mean_k = mean_k + (x_k - mean_{k-1}) / k
  --   T_k = T_{k-1} + (k - 1) * (x_k - mean_{k-1})^2 / k
  --   s^2 = T_m / (m - 1)
  --   Equivalently: mean_0 = T_0 = 0.
  -- Reported in [Chen and Lewis 1979] to be preferrable
  -- to other variations (http://doi.acm.org/10.1145/359146.359152 (p.531)).
  --
  -- See also
  -- - Heiser. Microsoft Excel 2000, 2003 and 2007 Faults, Problems, Workarounds,
  --   and Fixes.  http://www.daheiser.info/excel/frontpage.html
  -- - T. Chan and J. Lewis. Computing standard deviations: Accuracy. 1979.
  --   http://doi.acm.org/10.1145/359146.359152
  -- - T. Chan, G. Golub, R. Leveque.
  --   Algorithms for Computing the Sample Variance: Analysis and
  --   Recommendations. 1983.  http://dx.doi.org/10.2307/2683386

  local mean = 0
  local T = 0
  for i,x in ipairs(t) do
    local d = x - mean
    local e = d / i
    mean = mean + e
    T = T + (i - 1) * d * e
  end
  return mean, T / (#t - 1)
end
--[[UNUSED: Alternative algorithms.

  -- Welford alorithm, 1962.
  -- Numerically stable online algorithm.
  -- B.P. Welford, Technometrics, 4,(1962), 419-420.
  -- Donald Knuth, "The Art of Computer Programming,
  -- Volume 2: Seminumerical Algorithms", section 4.2.2.
  -- http://en.wikipedia.org/wiki/Algorithms_for_calculating_variance
  --
  -- Defined by the recurrence relation:
  --   mean_1 = x_1, S_1 = 0
  --   mean_k = mean_(k-1) + (x_k - mean_(k-1)) / k
  --   S_k = S_(k-1) + (x_k - mean_(k-1)) * (x_k - mean_k)
  --   s^2 = S_n / (n-1)
  -- Equivalently: mean_0 = S_0 = 0.
  -- The West algorithm is a variation of this
  -- and is reported in [Chen and Lewis 1979] to be preferrable
  --   http://doi.acm.org/10.1145/359146.359152 (p.531)

  local mean, S = 0, 0
  for n,x in ipairs(t) do
    local d = x - mean
    mean = mean + d/n
    S = S + d * (x - mean)
  end
  return mean, S / (#t - 1)

  -- Two-pass algorithm (straight from the definition).
  -- Note: as noted by Heiser, the variance
  -- of {1e30,1e30,1e30} will be approx 2.97e+28 rather than 0,
  -- so the calculator algorithm will be preferred.

  local mean = M.array_mean(t)
  local s2 = 0
  for i,x in ipairs(t) do
    local d = (x - mean)
    s2 = s2 + d*d
  end
  return mean, s2/(#t - 1)

  -- Two-pass algorithm.  First pass subtracts mean.  Second pass uses
  -- textbook (calculator) algorithm:
  --   s^2 = (S(x^2) - (1/m)*(S(x))^2) / (m - 1)
  -- where S(x) and S(x^2) are the sums and sum squares of the data values.
  --
  -- Note: as noted by Heiser, the calculator algorithm is used instead
  -- of summing the squared deviations since with the latter, the variance
  -- of {1e30,1e30,1e30} will be approx 2.97e+28 rather than 0.
  --
  -- This is also fairly accurate, but the Welford algorithm
  -- is also accurate and uses only one pass.

  local mean = M.array_mean(t)
  local s, s2 = 0, 0
  for n,x in ipairs(t) do
    local d = (x - mean)
    s = s + d
    s2 = s2 + d*d
  end
  return mean, (s2 - s*s / #t) / (#t - 1)
--]]

function M.array_variance(t)
  local a, b = M.array_mean_and_variance(t)
  return b
end

function M.array_stdev(t)
  local v = M.array_variance(t)
  return v and sqrt(v)
end

-- Halton sequence generator. http://en.wikipedia.org/wiki/Halton_sequence
-- Generates up to base^n - 1 values (default n = 48).
-- Improves efficiency with a code generation technique that avoids bit
-- shifting, floating point, and modulo arithmetic in Lua.
-- Based on patterns in differences between successive elements.
-- In fact, this is about the same speed (or 1/3 the speed under LuaJIT)
-- as a conventional implementation in C, or three times the speed
-- of a conventional Lua implementation.
-- D.Manura, 2007-08.
local function helper(base, n, nmax)
  local pow = base^n
  local diff = - (pow-base-1) / pow
  local code = (n == nmax) and "assert(false)" or helper(base, n+1,nmax)
  local s = "if a$(n) ~= 0 then a$(n) = a$(n) - 1; diff = $(diff) " ..
            "else a$(n) = $(basem); $(code) end"
  s = s:gsub("$%((%w+)%)", {n = n, diff = diff, code = code, basem = base-1})
  return s
end
local function make_halton(base, n)
  n = n or 48
  local s = "local h = 0; "
  for i=1,n do s = s .. "local a" .. i .. " = " .. (base-1) .. "; " end
  s = s .. "return function() local diff; " .. helper(base, 1, n) ..
           "; h = h + diff; return h end"
  local f = assert(loadstring(s))()
  return f
end
M.make_halton = make_halton

local histogram_type = {}
--histogram_type.__index = histogram_type

local argtypes
function M.make_histogram(t)
  argtypes = argtypes or Type {
    data = Type.number_array,
    min = Type.number + Type['nil'],
    max = Type.number + Type['nil'],
    nbins = Type.nonnegative_integer + Type['nil'],
    binsize = Type.nonnegative_number + Type['nil'],
    centerbins = Type.boolean + Type['nil'],
    normalize = Type.boolean + Type['nil']
  }
  argtypes:check(t, 2)
  local data = t.data
  local centerbins = t.centerbins;
    if centerbins == nil then centerbins = not (t.min or t.max) end
  local min = t.min or M.array_min(data) or 0
  local max = t.max or M.array_max(data) or min
  local span = max - min
  assert(span >= 0)
  assert(not(span == 0 and t.nbins ~= nil and t.nbins > 1))
  assert(not(span > 0 and t.binsize ~= nil and t.binsize == 0))
  assert(not(t.nbins and t.binsize))
  -- local nbins = num_bins or math.sqrt(math.max(#data, 1))
  local nbins = t.nbins
  local binsize = t.binsize
  if not nbins and not binsize then
    nbins = #data <= 10 and #data or
            math.floor(10 * math.log10(#data))
    binsize = nbins > 1 and span / (nbins - (centerbins and 1 or 0)) or span
  elseif nbins then
    binsize = nbins > 1 and span / (nbins - (centerbins and 1 or 0)) or span
  else -- binsize
    nbins = (#data == 0) and 0 or span / binsize + (centerbins and 1 or 0)
  end
  if centerbins then
    min = min - binsize / 2
    max = max + binsize / 2
    span = max - min
  end
  local normalize = t.normalize
    if t.normalize == nil then normalize = true end

  local count = 0
  local frequencies = {};
  for n=1,nbins do
    frequencies[n] = 0
  end
  local midpoints = {};
  for n=1,nbins do
     local p = (n - 0.5) / nbins
     midpoints[n] = p * span + min
  end
  for _,v in ipairs(data) do
    local p = (span == 0) and 0 or (v - min) / span
    local idx = math.floor(p * nbins * 0.99999) + 1
    if idx >= 1 and idx <= nbins then
      frequencies[idx] = frequencies[idx] + 1
      count = count + 1
    end
  end
  -- normalize
  if normalize and count ~= 0 then
    local dx = span / nbins
    local factor = count * dx

    for n = 1,nbins do
      frequencies[n] = frequencies[n] / factor
    end
  end
  return setmetatable({
    midpoints = midpoints, frequencies = frequencies,
    npoints = #data,
    binmin = min, binmax = max, nbins = nbins,
    binsize = binsize, centerbins = centerbins,
    normalize = normalize
  }, histogram_type)
end

function histogram_type:__tostring()
  local midpoints = self.midpoints
  local frequencies = self.frequencies

  local s = string.format(
    "{npoints=%d,nbins=%d,binmin=%f,binmax=%f,binsize=%f,centerbins=%s,normalize=%s}\n",
    self.npoints, self.nbins, self.binmin, self.binmax, self.binsize,
    self.centerbins and "true" or "false", self.normalize and "true" or "false"
  )

  for n=1,#midpoints do
    s = s .. string.format("%f,%f\n", midpoints[n], frequencies[n])
  end
  return s
end

return M
