--[[
  sheets_2dcyl.lua
 
  This is similar to field2dplanar.lua.  See that file for background.
  This example differs in that it solves a system in 2D cylindrical symmetry.
 
  D.Manura, 2011-12-15, 2008-02.
  (c) 2008-2011 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]


local C = require "simionx.Constants"  -- common physical constants
local UTIL = simion.import "../palib.lua"

--[[
  Returns a table describing the potential, boundary points, and
  charge density for the system described below.  The returned table
  contains these fields:
 
   `potential`
      A function that maps position (x,y,z) in mm to
      theoretical potential at that point.
   `boundary`
      A function that maps position (x,y,z) in mm to
      a Boolean indicating whether the given point is on the
      boundary, i.e. forming a boundary condition.
   `charge`
      A function that maps position (x,y,z) in mm to
      the charge density in C mm^-3 at that point.
   `size`
      A table {wx=wx, wy=wy, wz=wz} describing the
      lengths of the solution space in mm in the x, y, and z
      dimensions.  solution space is assumed to be inside the
      rectangle with vertices (x,y,z)=(0,0,0) to (x,y,z)=(wx,wy,wz).
      wz may be nil to indicate 2D symmetry.
 
  This data may be used elsewhere to set up arrays that represent
  this system so that the system can be solved (Refined) in SIMION.
  The data also provides theoretical potentials in which to compare
  the SIMION results against theory.

  Setup:
 
  A cylinder volume is partitioned into N cylindrical sheets of
  infinite length and uniform charge with relative charge densities
  k_i (unitless), inner diameter R_{i-1} (mm) and outer diameter R_i
  (mm) for i=1..N.  R_N is held at potential V.  The relative charge
  densities are scaled such that potential becomes 0 on the axis.  By
  convention, we'll also define k_0 = k_{-1} and R_0=0.
 
  Discussion:
 
  The Poisson equation in cylindrical symmetry for this system is
 
    (1/r) <d/dr> r <dPhi(r)/dr> = k(r)
    where k(r) = -rho(r)/epsilon_0 = k_i when R[i-1] <= r < R[i].
 
  subject to the boundary conditions
 
    <dPhi/dr>|r=0 = 0  (due to mirror symmetry on-axis)
    Phi(r=R_N) = V     (due to electrode)
 
  Phi(r) is a piecewise continuous function with parts Phi_i(r)
  defined over R[i-1] <= r < R[i].  These functions are subject to
  the restriction
 
    <dPhi_i/dr>|r=R_i = <dPhi_{i+1}/dr>|r=R_i and
    Phi_i(r=R_i) = Phi_{i+1}(r=R_i)
    for i=1..N-1.
 
  This can be solved in a straight manner by integration and has the
  following solution:
 
    Phi_i(r) = b_i + (k_i / 4) r^2 + c_i * ln(r)
    where
      a_i = (k_i - k_{i+1}) R_{i}^2  (i not equal to N)
      c_i = (1/2) SUM_{j=1..i-1} a_j
      b_i = (1/2) c_i
          - (1/2) SUM_{j=1..i-1} a_j ln(R_j)
      for i=1..N
--]]
local function system5(R,k,V)
  -- Build arrays of constants.
  local a = {}
  local b = {}
  local c = {}
  for i=1,#R do
    if i ~= #R then
      a[i] = (k[i] - k[i+1]) * R[i]^2
    end
    local sum1 = 0
      for j=1,i-1 do
        sum1 = sum1 + a[j] * math.log(R[j])
      end
    local sum2 = 0
      for j=1,i-1 do
        sum2 = sum2 + a[j]
      end
    c[i] = (1/2) * sum2
    b[i] = (1/2) * c[i] - (1/2) * sum1
  end

  -- voltage scaling factor
  local d = 1  -- initial value (updated later)

  local sys = {}
  function sys.potential(x,y)
    y = math.min(y, R[#R])
    local i = 1
    while R[i] < y do i = i + 1 end
    assert((i==1 and 0 or R[i-1]) <= y and y <= R[i])
    return d * (b[i] + (k[i]/4)*y^2
                      + c[i]*(y == 0 and 0 or math.log(y)))
  end
  local vmax = sys.potential(0,R[#R])
  assert(vmax > 0 and vmax < math.huge, vmax)
  d = V / vmax  -- rescale

  function sys.boundary(x,y)
    return y==R[#R]
  end
  function sys.charge(x,y) -- C/mm^3
    if y >= R[#R] then
      return 0
    else
      local i = 1
      while R[i] < y do i = i + 1 end
      local rho = -k[i]*d * (C.ELECTRIC_CONSTANT_F_M*1E-3)
      return rho
    end
  end
  sys.size = {wx=R[#R], wy=R[#R], wz=nil}
  return sys
end


-- You may wish to experiment with changing the
-- values in the system and grid definitions below.

-- Create system definition.
local R = {}
local k = {}
local V = 1
R[1] =  9; k[1] = 0
R[2] = 10; k[2] = 1
R[3] = 30; k[3] = 0
R[4] = 31; k[4] = 1
R[5] = 40; k[5] = 0
local sys = system5(R,k,V)

-- Create specification for solution grid.
local gridspec = {
  symmetry='2dcylindrical',   -- array symmetry.
  --d_mm=1,         -- grid scaling factor (mm gu^-1) for potential array.
  dx_mm=3,
  dy_mm=1/2,
  N=0                  -- charge array density is reduced further by a factor of 2^N.
}

-- SIMION Refine parameters.
local convergence_objective = 1e-5   -- (V)


-- Remove all PAs from RAM.
simion.pas:close()

-- Build the problem arrays.
local pa  = UTIL.build_boundary_potential_array(gridspec, sys)
local pac = UTIL.build_charge_array            (gridspec, sys)

-- Refine the system.  Note that the space-charge array
-- is passed as a parameter for Poisson solving.
pa:refine{charge=pac, convergence=convergence_objective}

-- Create a theoretical potential array (pad) and compare the refined
-- solution to it (i.e. pad = pa - pat).
local pat = UTIL.build_theoretical_potential_array(gridspec, sys)
local pad, abs_err,rel_err = UTIL.build_difference_array(pa, pat)

-- Optionally save the arrays to disk.
pa:save  'test.pa'
pac:save 'test-charge.pa'
pat:save 'test-theoretical.pa'
pad:save 'test-difference.pa'

-- Display errors.  Relative error should be a small fraction
-- of 1 if the SIMION Refine was done correctly.
print('Absolute error=', abs_err, 'Relative error=', rel_err)
