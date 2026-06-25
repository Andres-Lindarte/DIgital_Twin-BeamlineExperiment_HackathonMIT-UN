-- multipole_expansion.lua
-- Lua module - Computes multipole components of potential.
-- Solves a system of linear equations with matrix methods.
-- D.Manura, 200707

-- Note: the matrix library is based on
-- http://lua-users.org/wiki/SimpleMatrix .
local matrix = require "matrix"

local M = {}

-- Multipole components.
local f = {
  function(z,r) return 1 end,
  function(z,r) return z end,
  function(z,r) return (-1/2)*r*r + z*z end,
  function(z,r) return (-3/2)*r*r*z + z*z*z end,
  function(z,r) return (3/8)*r^4 - 3*r*r*z*z + z^4 end,
  function(z,r) return (15/8)*r^4*z - 5*r*r*z*z*z + z^5 end,
  function(z,r) return (-5/16)*r^6 + (45/8)*r^4*z*z - (15/2)*r*r*z^4 + z^6 end
}

-- Builds list of <npoints> evenly spaced
-- points along a circle of radius <radius>, centered at the origin.
-- Returns <xs>, <ys>, which are arrays containing the x and y
-- coordinates respectively for each point.
local function make_points(radius, npoints)
  -- Build list of evaluation points.
  local xs, ys = {}, {}
  for i=1,npoints do
    local theta = (i-1) / (npoints-1) * 2 * math.pi
    local x = math.floor(math.cos(theta) * radius)
    local y = math.floor(math.sin(theta) * radius)
    xs[#xs+1] = x
    ys[#ys+1] = y
  end
  --for i=1,#xs do print(i, xs[i], ys[i]) end

  return xs, ys 
end

function M.resolve(t)
  local origin = t.origin or {0,0}
  local x0 = origin[1] or 0
  local y0 = origin[2] or 0

  --UNUSED:
  --local region = t.region or {{0,0}, {5,5}}
  --local xmin,ymin,xmax,ymax
  --    = region[1][1], region[1][2], region[2][1], region[2][2]

  local radius = t.radius or 20

  local npoints = t.npoints or 30

  local potential = assert(t.potential, "potential not specified")

  -- If a SIMION array
  if type(potential) == "userdata" and
     type(potential.potential) == "function"
  then
    local pa = potential
    potential =
      function(x,y)
        if x < 0 then x = -x end  -- assume mirroring if out of bounds
        if y < 0 then y = -y end  -- ""
        if pa:electrode(x,y,0) then
          error(string.format("test point (%g,%g) inside electrode", x,y))
        end
        return pa:potential(x,y,0)
      end
  end

  local rscale = t.rscale or 1
  local vscale = t.vscale or 1

  -- Build list of evaluation points.
  -- local xs, ys = make_points_boxfill(xmin, ymin, xmax, ymax, npoints)
  local xs, ys = make_points(radius, npoints)

  -- Build matrix equation A * C = B
  local A = matrix(#xs,#f)
  local B = matrix(#xs,1)
  for i=1,#xs do
    local x, y = xs[i], ys[i]
    for j=1,#f do
      A[i][j] = f[j](x,y)
    end
    B[i][1] = potential(x+x0, y+y0)
  end
  -- print(A, '\n--\n', B, '\n--')

  -- Solve for C's.
  local C = (A:transpose() * A)^-1 * A:transpose() * B
  -- local C, info = matrix.lss(A, B)

  -- Scale
  for i=1,#f do
    C[i][1] = C[i][1] * rscale^(i-1) / vscale
  end
  -- print('---\n', C)

  local CT = C:transpose()[1]

  local result = {}
  for i=1,#f do result[i] = CT[i] end

  return result
end

function M.print_result(t)
  print("---")
  print("i,C_i")
  for i=1,#t do print(string.format("%d,%e", i-1, t[i])) end
  print("---")
end

-- TEST (if run as a batch mode program rather than loaded as a module).
if not ... then
  print("TEST: Resolving an analytic potential...")
  local result = M.resolve {
    potential = function(z,r) return
      5 +
      2 * (z) +
      3 * (-0.5*r^2 + z^2) +
      4 * ((-3/2)*r*r*z + z*z*z) +
      7 * ((3/8)*r^4 - 3*r*r*z*z + z^4) +
      1 * ((15/8)*r^4*z - 5*r*r*z*z*z + z^5) +
      6 * ((-5/16)*r^6 + (45/8)*r^4*z*z - (15/2)*r*r*z^4 + z^6)
     end
   }
   assert(math.abs(result[1] - 5) < 1e-6)
   assert(math.abs(result[2] - 2) < 1e-6)
   assert(math.abs(result[3] - 3) < 1e-6)
   assert(math.abs(result[4] - 4) < 1e-6)
   assert(math.abs(result[5] - 7) < 1e-6)
   assert(math.abs(result[6] - 1) < 1e-6)
   assert(math.abs(result[7] - 6) < 1e-6)
   print("SUCCESS")

   -- These options may be used too:
   -- potential = simion.pas[1],  -- use a real SIMION array instead
   -- origin = {0,0},
   -- radius = 25,
   -- npoints = 20,
   -- rscale = 1,
   -- vscale = 1
end

return M


-- UNUSED.  This gives results less consistent with the paper.
-- Builds list of npoints number of evenly spaced
-- points in the closed rectangular region (xmin,ymin)
-- to (xmax,ymax).
-- Returns xs, ys, which are arrays containing the x and y
-- coordinates respectively for each point.
--local function make_points_boxfill(xmin, ymin, xmax, ymax, npoints)
--  local xwidth = (xmax-xmin+1)
--  local ywidth = (ymax-ymin+1)
--  local size = xwidth * ywidth
--  local skip = math.floor((size-1) / npoints) + 1
--
--  -- Build list of evaluation points.
--  local xs, ys = {}, {}
--  for i=1,npoints do
--    local pos = (i-1) * skip
--    local x = pos % xwidth
--    local y = math.floor(pos / xwidth)
--    xs[#xs+1] = x
--    ys[#ys+1] = y
--  end
--  --for i=1,#xs do print(i, xs[i], ys[i]) end
--
--  return xs, ys 
--end
