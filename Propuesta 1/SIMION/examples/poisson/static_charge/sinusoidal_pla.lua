--[[
 sinusoidal_pla.lua

 This is a batch mode Lua program that illustrates solving a simple
 space-charge field with the Poisson solver.  The geometry is of a
 simple system with a known theoretical solution so that accuracy
 can be tested.  See the description of the system in the system2
 function below.

 This program builds a potential array defining the boundary
 condition potentials (electrodes) of the system.  It also builds a
 corresponding space-charge array defining the space-charge density
 distribution inside that volume.  Then it refines the potential
 array given the space-charge array as a parameter.  That determines
 the potentials (and fields) inside the volume space.
  
 Additionally, for checking accuracy, an array containing
 theoretical potentials is constructed and subtracted from the
 refined potential array to compute absolute and relative errors,
 which are displayed when the program completes.

 It can be useful to superimpose the refined array (test.pa) and
 with the theoretical array (test-theoretical.pa) on a workbench.
 Enable the PE and/or contour views.  The potentials of the two
 arrays should be near identical (temporarily change to positioning
 of one array in the PAs tab to confirm that there really are two
 potential energy surfaces that overlap, or view the difference
 array, test-diffference.pa).

 The code here is more complicated than strictly necessary, but it
 is quite general.  For example, it is easy to try altering the
 parameters of the system or adapt this test to other problems.

 VERSION NOTICE: This program relies on features in SIMION 8.1.0.

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
 
 A hollow, conductive 3D rectangular box is constructed in the Cartesian
 coordinate system with vertices (x,y)=(0,0,0) to (x,y,z)=(L,M,N), where
 positions are in units of mm.  The potential on the
 sides x=0 and x=L are Vleft and Vright respectively, and the other sides
 are linear gradients for x in between.  The charge density inside
 the tube is defined to be
  
    rho(x,y,z) = rho_max * sin(i PI x/L) * sin(j PI y/M) * cos(k PI z/N)
	
 for some positive integers i, j, k and some maximum charge density
 rho_max in units of C mm^-3.
  
 As a special case, for 2D planar symmetry, we'll set k = 0.  In the below
 code, setting N = 0 will be treated as 2D planar symmetry.
 
 Discussion:
 
 When V_left = V_right = 0, the the theoretical solution can be
 determined by solving the Poisson equation:
 
    Del^2 Phi(x,y) = (-rho_max/epsilon0)*sin(i PI x/L)*sin(j PI y/M)*cos(k PI z/N).
 
 By inspection, we see
 
    Phi(x,y) = A * sin(i PI x/L) * sin(j PI y/M) * cos(k PI z/N)
 
 for some constant A, which we can solve to find
 
    A = rho_max / [epsilon_0 * PI^2 * ((i/L)^2 + (j/M)^2 + (k/N)^2)]
 
 For other values of V_left and V_right, a linear gradient is
 superimposed on the above solution.
--]]
local function system2(L,M,N,i,j,k,rho_max, Vleft,Vright)
  local k_over_N = (N == 0) and 0 or k/N
  local PI  = math.pi
  local sin = math.sin
  local cos = math.cos
  local A = (rho_max * 1E+9)
    / (C.ELECTRIC_CONSTANT_F_M * PI^2 * ((i/(L*1E-3))^2 + (j/(M*1E-3))^2 + (k_over_N/(1E-3))^2))

  local sys = {}
  function sys.potential(x,y,z)
    return A * sin(i*PI*x/L) * sin(j*PI*y/M) * cos(k_over_N*PI*z)
           + (Vleft + (Vright - Vleft) * x/L)
  end
  function sys.boundary(x,y,z)
    return x == 0 or x == L or
           y == 0 or y == M or
           N ~= 0 and (z == 0 or z == N)
  end
  function sys.charge(x,y,z)
    return rho_max * sin(i*PI*x/L) * sin(j*PI*y/M) * cos(k_over_N*PI*z)
  end
  sys.size = {wx = L, wy = M, wz = N}

  return sys
end


-- You may wish to experiment with changing the
-- values in the system and grid definitions below.

-- Create system definition.
local L = 48           -- (mm)
local M = 64           -- (mm)
local N = 10            -- (mm), note: set to 0 for 2D symmetry
local i = 2            -- (positive integer)
local j = 3            -- (positive integer)
local k = 2            -- (positive integer), note: forced to zero for 2D symmetry
local Vleft = 10       -- (V)
local Vright = 1       -- (V)
local rho_max = 2e-15  -- (C mm^-3)
local sys = system2(L,M,N,i,j,k,rho_max,Vleft,Vright)

-- Create specification for solution grid.
local gridspec = {
  symmetry=(N == 0 and '2dplanar' or '3dplanar'), -- array symmetry.
  -- d_mm=1,         -- grid scaling factor (mm/gu) for potential array.
  dx_mm=1/2,
  dy_mm=1/3,
  dz_mm=1/4,
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
