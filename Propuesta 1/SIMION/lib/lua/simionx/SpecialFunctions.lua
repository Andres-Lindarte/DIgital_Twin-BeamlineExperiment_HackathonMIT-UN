-- simionx.SpecialFunctions
-- This module is documented in the SIMION supplemental documentation.
-- version: 20070816
-- (c) 2007 Scientific Instrument Services, Inc. (SIMION 8.0 License)

local Sup = require "simionx.Support"

local abs  = math.abs
local exp  = math.exp
local max  = math.max
local min  = math.min
local sqrt = math.sqrt
local pi   = math.pi

local M = Sup.module()

-- load faster C implementations
simion._load_implementation("simionx.SpecialFunctions", M)


--[[
function M.erf(z)
  -- This algorithm is quite accurate.  It is based on
  -- "Q-Function Handout" by Keith Chugg:
  --   http://tesla.csl.uiuc.edu/~koetter/ece361/Q-function.pdf
  -- See also http://www.theorie.physik.uni-muenchen.de/~serge/erf-approx.pdf
  -- I also find that the following makes a reasonable approximation:
  --   1 - exp(-(2/sqrt(pi))x - (2/pi)x^2)

  local za = abs(z)
  local res
  if za > 10 then res = 1
  elseif za == 0 then res = 0
  else
    local t = 1 / (1 + 0.32759109962 * za)
    res = (    - 1.061405429 ) * t
    res = (res + 1.453152027 ) * t
    res = (res - 1.421413741 ) * t
    res = (res + 0.2844966736) * t
    res =((res - 0.254829592 ) * t) * exp(-za*za)
    res = res + 1
  end
  if z < 0 then res = -res end
  return res
end
--]]

-- floating point limits
local dbl_max = 1e+308
local dbl_min = 3e-308
local lolim = dbl_min * 5
local hilim = dbl_max / 5

-- max relative fractional error expressed as |theory-calc|/|calc|.
local relative_error = 1e-7

local nan = 0; nan = nan / nan -- not-a-number

do
  local tolerance = (3 * relative_error)^(1/6)
function M.elliptic_rf(x, y, z)
  if not(
    x >= 0 and y >= 0 and z >= 0 and
    x+y >= lolim and x+z >= lolim and y+z >= lolim and
    x <= hilim and y <= hilim and z <= hilim
  ) then return nan end

  -- Algorithm based on that by Carlson94.
  -- The Duplication Thoerem is iterated until arguments
  -- are almost equal.  Then function is expanded in Taylor
  -- series to fifth order.
  --
  -- The Duplication Theorem is
  -- RF(x,y,z) = 2*RF(x + lambda,   y + lambda,   z + lambda)
  --           =   RF((x+lambda)/4, (y+lambda)/4, (z+lambda)/4)
  -- where
  --   lambda = sqrt(x*y) + sqrt(y*z) + sqrt(z*x)
  -- This can be applied repeatedly to rewrite RF.
  -- In doing so, the x, y, and z approach equality.
  --
  -- See also
  -- * http://en.wikipedia.org/wiki/Carlson_symmetric_form
  -- * http://boost-consulting.com/vault/index.php?action=downloadfile&
  --        filename=math_toolkit.pdf&directory=Math%20-%20Numerics&
  -- * http://nvl.nist.gov/pub/nistpubs/jres/107/5/j75car.pdf
  -- * Carlson94 http://arxiv.org/abs/math.CA/9409227
  --   Numerical computation of real or complex elliptic integrals
  -- * Carlson93 http://arxiv.org/abs/math/9310223
  --   Asymtotic Approximations for Symmetric Elliptic Integrals
  -- * B. C. Carlson and E. M. Notis, Algorithms for incomplete
  --     elliptic integrals, ACM Transactions on Mathematical
  --     Software 7, 3 (September 1981), pp. 398-403.
  -- * Carlson79 B. C. Carlson, Computing elliptic integrals by
  --     duplication, Numerische Mathematik 33, (1979), pp. 1-16.
  ---    http://www.springerlink.com/content/q4122876627860x4/
  -- * B. C. Carlson, Elliptic integrals of the first kind,
  --     SIAM Journal of Mathematical Analysis 8, (1977),
  --     pp. 231-242.

  -- m = 0.
  local x_m, y_m, z_m = x, y, z
  local mean_m = (x + y + z) * (1/3)
  local devx, devy, devz  -- fractional differences X,Y,Z
  while true do  -- loop m = 0..n
    -- Test for error tolerance.
    devx = 1 - x_m / mean_m  -- X
    devy = 1 - y_m / mean_m  -- Y
    devz = -(devx + devy)   -- Z == -(X+Y) == 1 - z_m / mean_m
    local epsilon = max(abs(devx), abs(devy), abs(devz))
    if epsilon < tolerance then break end  -- m == n

    -- next iteration of m.
    local sqrtx_m = sqrt(x_m)
    local sqrty_m = sqrt(y_m)
    local sqrtz_m = sqrt(z_m)
    local lambda_m = sqrtx_m * (sqrty_m + sqrtz_m) + sqrty_m * sqrtz_m
    x_m = (x_m + lambda_m) * (1/4)
    y_m = (y_m + lambda_m) * (1/4)
    z_m = (z_m + lambda_m) * (1/4)
    mean_m = (mean_m + lambda_m) * (1/4) -- =(x_m+y_m+z_m)/3
  end

  -- Now perform Taylor expansion on the fractional differences with
  -- elementary symmetric functions:
  --   E1 = X + Y + Z = X + Y - (X + Y) = 0
  --   E2 = XY + XZ + YZ = XY + (X+Y)Z = XY - Z^2
  --   E3 = XYZ
  local E2 = devx * devy - devz*devz
  local E3 = devx * devy * devz
  -- RF = A_n^(-1/2) * (1 - (1/10)E2 + (1/14)E3 + (1/24)E2^2 - (3/44)E2E2)
  return (1 + (1/14)*E3 + ((-1/10) + (1/24)*E2 - (3/44)*E3)*E2) / sqrt(mean_m)
end end

do
  local tolerance = (relative_error / 4)^(1/6)
function M.elliptic_rd(x, y, z)
  if not(
    x >= 0 and y >= 0 and z >= lolim and
    x+y >= lolim and
    x <= hilim and y <= hilim and z <= hilim
  ) then return nan end

  -- Algorithm based on that by Carlson94.

  local x_m, y_m, z_m = x, y, z
  local mean_m = (x + y + 3*z) * (1 / 5)
  local devx, devy, devz
  local extra = 0
  local power_m = 1
  while true do  -- loop m = 0..n
    devx = 1 - x_m / mean_m
    devy = 1 - y_m / mean_m
    devz = 1 - z_m / mean_m
    local epsilon = max(abs(devx), abs(devy), abs(devz))

    if epsilon < tolerance then break end  -- m == n

    -- next iteration of m
    local sqrtx_m = sqrt(x_m)
    local sqrty_m = sqrt(y_m)
    local sqrtz_m = sqrt(z_m)
    local lambda_m = sqrtx_m * (sqrty_m + sqrtz_m) + sqrty_m * sqrtz_m

    -- extra = sum from m=0 to n-1 of 4^(-m)/(sqrt(z_m)*(z_m + lambda_m))
    extra = extra + power_m / (sqrtz_m * (z_m + lambda_m))
    power_m = power_m * (1/4)

    x_m = (x_m + lambda_m) * (1/4)
    y_m = (y_m + lambda_m) * (1/4)
    z_m = (z_m + lambda_m) * (1/4)
    mean_m = (mean_m + lambda_m) * (1/4)
  end

  local devz2 = devz*devz
  local devxdevy = devx * devy
  local E2 = devxdevy - 6 * devz2
  local E3 = (3 * devxdevy - 8 * devz2) * devz
  local E4 = 3 * (devxdevy - devz2)*devz2
  local E5 = devxdevy * devz2 * devz

  -- RD = 4^(-n)*mean_n^(-3/2)*(1-(3/14)E2+(1/6)E3+(9/88)E2^2-(3/22)E4-(9/52)E2E2+(3/26)E5)
  return power_m * (1/(mean_m*sqrt(mean_m))) * (1 + ((-3/14) + (9/88)*E2 - (9/52)*E3)*E2
                                                + (1/6)*E3 - (3/22)*E4 + (3/26)*E5)
         + 3 * extra
end end

do
  local fr = 2.7 * sqrt(relative_error)
function M.elliptic_rf0(x,y)
  if not (x >= lolim and y >= lolim) then return nan end

  local xm, ym = sqrt(x), sqrt(y)
  while abs(xm - ym) >= fr * abs(xm) do
    xm, ym = (xm + ym)*(1/2), sqrt(xm * ym)  
  end
  return pi / (xm + ym)
end end

-- [undocumented]
-- This is the same as rf(x,y,0), 2*rg(x,y,0) -- but should be a bit faster
-- Assumes x,y both non-zero.
-- Computes both RF and RG together (faster).
-- x,y >= 0
do
  local fr = 2.7 * sqrt(relative_error)
function M.elliptic_rf0rg20(x,y)
  if not(
    x > 0 and y > 0 and x+y >= lolim and x <= hilim and y <= hilim
  ) then return nan end

  -- m = 0
  local power2 = (1/4)
  local extra = 0
  local x0, y0 = sqrt(x), sqrt(y)
  local xm, ym = x0, y0   -- note: abs(xm) == xm
  while abs(xm - ym) >= fr * xm do -- m = 0..n
    -- next iteration
    xm, ym = (xm + ym)*(1/2), sqrt(xm * ym)  
    power2 = power2 * 2

    -- extra = sum from m=1 to n of 2^(m-2)*(x_m - y_m)^2
    local f1 = (xm - ym)
    extra = extra + power2 * f1 * f1
  end
  local rf = pi / (xm + ym)
  local f2 = (x0+y0)*(1/2)
  local rg2 = (f2*f2 - extra) * rf

  return rf, rg2
end end


function M.elliptic_rg0(x,y)
  local rf0, rg20 = M.elliptic_rf0rg20(x,y)
  return rg20 * (1/2)
end

function M.elliptic_rc(x,y)
  return M.elliptic_rf(x,y,y)  -- by definition
end

do
  local tolerance = (relative_error / 4)^(1/6)
function M.elliptic_rj(x,y,z,p)
  -- Algorithm based on that by Carlson94.

  -- m=0
  local x_m, y_m, z_m, p_m = x, y, z, p
  local mean_m = (x + y + z + 2*p)*(1/5)
  local devx, devy, devz, devp
  local extra = 0
  local delta = (p - x) * (p - y) * (p - z)
  local power43_m = delta
  local power4_m = 1
  while true do  -- m=0..n

    devx = 1 - x_m / mean_m
    devy = 1 - y_m / mean_m
    devz = 1 - z_m / mean_m
    devp = (-1/2)*(devx + devy + devz)

    local epsilon = max(abs(devx), abs(devy), abs(devz), abs(devp))

    if epsilon < tolerance then break end  -- m == n

  
    local sqrtx_m = sqrt(x_m)
    local sqrty_m = sqrt(y_m)
    local sqrtz_m = sqrt(z_m)
    local sqrtp_m = sqrt(p_m)
    local lambda_m = sqrtx_m * (sqrty_m + sqrtz_m) + sqrty_m * sqrtz_m
    local d_m = (sqrtp_m + sqrtx_m)*(sqrtp_m + sqrty_m)*(sqrtp_m + sqrtz_m)
    local e_m = power43_m / (d_m*d_m)

    extra = extra + (power4_m / d_m) * M.elliptic_rc(1, 1 + e_m)

    x_m = (x_m + lambda_m) * (1/4)
    y_m = (y_m + lambda_m) * (1/4)
    z_m = (z_m + lambda_m) * (1/4)
    p_m = (p_m + lambda_m) * (1/4)
    mean_m = (mean_m + lambda_m) * (1/4)
    power43_m = power43_m * (1/(4*4*4))
    power4_m = power4_m * (1/4)
  end

  local devxy = devx * devy
  local devxyz = devxy * devz
  local devp2 = devp * devp
  local devp3 = devp2 * devp
  local E2 = devxy + (devx + devy) * devz - 3*devp2
  local E3 = devxyz + 2 * E2 * devp + 4 * devp3
  local E4 = (2*devxyz + E2*devp + 3*devp3)*devp
  local E5 = devxyz * devp2

  return power4_m * (1/(mean_m*sqrt(mean_m))) *
         (1 + ((-3/14) + (9/88)*E2 - (9/52)*E3)*E2
            + (1/6)*E3 - (3/22)*E4 + (3/26)*E5)
         + 6 * extra         
end end

--[[DISABLED:
function M.elliptic_k(k)
  local f = 1 - k*k
  return f == 0 and math.huge or M.elliptic_rf0(f, 1)
end
--]]

--[[DISABLED:
function M.elliptic_ke(k)
  local f = 1 - k*k
  if f == 0 then
    return math.huge, 1
  else
    return M.elliptic_rf0rg20(f, 1)  -- [Carlson94 55,56]
  end
end
--]]

--[[DISABLED:
function M.elliptic_e(k)
  local ek, ee = M.elliptic_ke(k)
  return ee
end
--]]

return M
