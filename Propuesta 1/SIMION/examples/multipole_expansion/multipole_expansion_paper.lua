-- multipole_expansion_paper.lua
-- Lua module - Computes coefficients C_n of the multipole expansion
-- of a cylindrically symmetric potential Phi:
--
--   Phi = V SUM[n=0..infinity] (C_n/r_0^n) Phi_n  (FIX?)
--
-- where Phi_n are the multipole solutions:
--
--   Phi_0 = 1
--   Phi_1 = z
--   Phi_2 = -(1/2)r^2 - z^2
--   Phi_3 = -(3/2)r^2 z + z^3
--   Phi_4 =  (3/8)r^4 - 3r^2 z^2 + z^4
--   Phi_5 =  (15/8)r^4 z - 5 r^2 z^3 + z^5
--   Phi_6 = -(5/16)r^6 + (45/8)r^4 z^2 - (15/2)r^2 z^4 + z^6
--   ...
--
-- This method is based on the paper
--
--   Barlow S.E.1; Taylor A.E.; Swanson K.
--   Determination of analytic potentials from finite element computations
--   International Journal of Mass Spectrometry,
--   Volume 207, Number 1, 12 April 2001, pp. 19-29(11)
--   http://dx.doi.org/10.1016/S1387-3806(00)00452-8
--
-- NOTE: THIS ALGORITHM AS WRITTEN DOESN'T SEEM TO WORK for some
-- reason (confirmed in Mathcad too).
--
-- D.Manura--200707.

-- Load Bessel function support.
local SF = require "simionx.SpecialFunctions"

local M = {}

local sin = math.sin
local cos = math.cos
local sinh = math.sinh
local cosh = math.cosh
local pi = math.pi

-- Compute k! for non-negative integer k.
local function factorial(k)
  local y = 1
  for n=2,k do y = y * n end
  return y
end

-- Numerical integration using J.Hollingsworth and H.Hunter, 1959.
-- [ http://doi.acm.org/10.1145/612201.612205 ]
-- Similar to Simpson's rule but allows odd number of intervals.
-- Integrates function f : R -> R over interval [a,b] at n equidistant
-- points on the interval.  If n unspecified, defaults to 1 unit between points.
local function integrate(f, a, b, n)
  if not n then assert((b-a) % 1 == 0) end
  n = n or b - a + 1

  local h = (n > 1) and (b-a)/(n-1) or 1
  local sum = 0
  if n >= 6 then
    sum = (3/8)*(f(a) + f(b)) + (7/6)*(f(a+h) + f(b-h)) + (23/24)*(f(a+2*h) + f(b-2*h))
    for j=3,n-4 do
      sum = sum + f(a + j*h)
    end
  elseif n == 2 then
    sum = (1/2)*(f(a) + f(b))
  elseif n == 3 then
    sum = (1/3)*(f(a) + f(b)) + (4/3)*f(a+h)
  elseif n == 4 then
    sum = (3/8)*(f(a) + f(b)) + (9/8)*(f(a+h) + f(b-h))
  elseif n == 5 then
    sum = (3/8)*(f(a) + f(b)) + (7/6)*(f(a+h) + f(b-h)) + (11/12)*f(a+2*h)
  end

  sum = sum * h

  return sum
end

local jn = SF.bessel_j0_zero


local function a1(t, s)
  local result = 
    2 / ((t.zt-t.zb)*SF.bessel_i0((1/2)*(2*s+1)*pi*t.c/(t.zt-t.zb))) *
    integrate(
      function(z) return t.potential(z,t.c)*cos((1/2)*(2*s+1)*pi*(2*z-t.zb-t.zt)/(t.zt-t.zb)) end,
      t.zb, t.zt
    )
  return result
end

local function a2(t, s)
  local result =
    2 / ((t.zt-t.zb)*SF.bessel_i0(4*s*pi*t.c/(t.zt-t.zb))) *
    integrate(
      function(z) return t.potential(z,t.c)*sin(2*s*pi*(2*z-t.zb-t.zt)/(t.zt - t.zb)) end,
      t.zb, t.zt
    )
  return result
end

local function a3(t, s)
  local result =
    2 / (t.c*t.c*sinh((t.zt-t.zb)*jn(s)/t.c) * SF.bessel_j1(jn(s))^2) *
    integrate(
      function(r) return t.potential(t.zb,r)*SF.bessel_j0(jn(s)*r/t.c)*r end,
      0, t.c
    )
  return result
end


local function a4(t, s)
  local result =
    2 / (t.c*t.c*sinh((t.zt-t.zb)*jn(s)/t.c) * SF.bessel_j1(jn(s))^2) *
    integrate(
      function(r) return t.potential(t.zt,r)*SF.bessel_j0(jn(s)*r/t.c)*r end,
      0, t.c
    )
  return result
end

local function cn(t, n, k)
  k = k or 10 --FIX, ok?
  local f1 = (n%2==0) and cos or sin
  local f2 = (n%2==0) and sin or cos
  local f3 = (n%2==0) and sinh or cosh
  local sign1 = ({[0]=1,1,-1,1,1,1,-1})[n]
  local sign2 = ({[0]=-1,1,-1,1,-1,-1,-1})[n]
  local sign3 = ((n-1)%4 < 2) and -1 or 1
  local factor2 = ({[0]=1, 4, 8, 32/3, 332/3, 128/15, 256/45})[n] --IMPROVE? generalize?
  local rnfactorial = 1/factorial(n)

  local sum = 0
  for s = 0, k do
    local c1 = pi*(t.zt+t.zb)/(t.zt-t.zb)
    sum = sum
        + sign1 * rnfactorial * a1(t,s)*(2*s+1)^n*f1((2*s+1)*c1)
        + sign2 * factor2     * a2(t,s)*   s   ^n*f2( 2*s   *c1)
  end
  sum = sum * (pi * t.c / (t.zt-t.zb))^n
  for s = 1, k do
    local js = jn(s)
    sum = sum
        + sign3 * rnfactorial * js^n * (a3(t,s)*f3(t.zt*js/t.c) - a4(t,s)*f3(t.zb*js/t.c))
  end
  return sum
end

function M.resolve(t)

  -- Boundary z=zb..zt and radius r=c.
  local zt = t.zt or 10
  local zb = t.zb or -10
  local c  = t.c  or 10

  local origin = t.origin or {0,0}
  local x0 = origin[1] or 0
  local y0 = origin[2] or 0

  local rscale = t.rscale or 1
  local vscale = t.vscale or 1

  local potential = assert(t.potential)

  -- If a SIMION array
  if type(potential) == "userdata" and type(potential.potential) == "function" then
    local pa = potential
    potential =
      function(x,y)
        if x < 0 then x = -x end  -- assume mirroring if out of bounds
        if y < 0 then y = -y end  -- ""
        assert(not pa:electrode(x+x0,y+y0,0))
        return pa:potential(x+x0,y+y0,0)
      end
  else -- shift
    local oldpotential = potential
    potential = function(x,y,z) return oldpotential(x+x0,y+y0,z) end
  end

  t = {zt = zt, zb = zb, c = c, potential = potential}

  -- DEBUG
  print(string.format("s=%d,a1s=%0.4g,a2s=%0.4g", 0, a1(t,0),a2(t,0)))
  for s=1,5 do
    print(string.format("s=%d,a1s=%0.4g,a2s=%0.4g,a3s=%0.4g,a4s=%0.4g",
                        s,a1(t,s),a2(t,s),a3(t,s),a4(t,s)))
  end

  local C = {}
  for i=1,7 do
    C[i] = cn(t,i-1)
  end

  -- Scale
  for i=1,7 do
    C[i] = C[i] * rscale^(i-1) / vscale
  end

  return C
end

function M.print_result(t)
  print("---")
  print("i,C_i")
  for i=1,#t do print(string.format("%d,%e", i-1, t[i])) end
  print("---")
end


-- TEST (if not loaded as module)
if not ... then

  M.print_result(M.resolve {
    potential = function(z,r) return 5 end,
    -- potential = function(z,r) return 0.5 * ((z/40)^2 - 0.5*(r/40)^2) end,
    zb = -40,
    zt = 40,
    c = 40,
    rscale = 1,
    vscale = 1
  })

  -- M.print_result(M.resolve{potential = simion.pas[1], origin = {1200,0}, rscale=400, vscale=1000, zb=-40, zt=40, c=40})

end

return M

-- UNUSED-OLD:
-- Numerical integration by Trapezoidal rule.
--local function integrate(f, a, b)
--  local sum = 0
--  for x=a,b-1 do
--    sum = sum + (f(x) + f(x+1)) / 2
--  end
--  return sum
--end
