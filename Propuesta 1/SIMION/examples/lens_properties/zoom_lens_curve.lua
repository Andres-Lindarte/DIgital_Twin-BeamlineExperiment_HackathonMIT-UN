--[[
 lens_curves.lua - SIMION Lua workbench user program.
 Generates "zoom lens" curve.

 For three element (zoom) lens, plots permitted voltages.
 Also plots magnifications and spherical and chromatic aberration
 coefficients.

 This is a quite instructive example of SIMION user programming,
 illustrating real-time Excel plotting, simplex optimization,
 and use of Lua coroutines to simplify automation of a series
 of runs.

 By default, this example plots results in Excel, but it can be
 easily customized to send results to some other program (e.g. maybe
 you have some other plotting program under Linux or have a
 custom routine of your own).  Just replace the record*
 functions with your own implementation.

 Comments:
 - Using Excel while SIMION is controlling it may cause the
   simulation to fail with an error message.
 - This program might not work if "Grouped" mode flying is enabled.
   (ensure "Grouped" is unchecked on the "Particles" tab).

 D.Manura, 2011-11-30,2007-10.
 (c) 2007-2011 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()


--## SECTION: ADJUSTABLE AND SYSTEM VARIABLES


-- Entrace lens voltage.
-- Note: voltage levels given below must be expressed relative to the zero
--   of particle KE.  That is, 0V corresponds to a potential at which the
--   particle would be at rest.  For example, if a 5 eV electron originates
--   in the entrance lens, then the voltages must be referenced such that the
--   entrance lens is measured at 5V (or -(5/2)V for a particle of +2 charge).
adjustable _V1 = 1    

-- Range of VA = V2/V1 values to scan, where V2 is center electrode.
adjustable _VA_min = 1/10   -- min bound
adjustable _VA_max = 10     -- max bound

-- Range of VB = V3/V1 values to scan, where V3 is exit electrode.
adjustable _VB_min = 1/10   -- voltage B min bound
adjustable _VB_max = 10     -- voltage B max bound

-- Number of data points to test.
-- This is the upper bound on the number of combinations of VA and VB
-- to plot (actual number plotted may be smaller).
adjustable _npoints = 100

-- Max focus spot radius accepted (mm) during voltage optimization routine.
-- Prevents plotting non-converged results.
-- A fraction of a grid unit is recommended.
adjustable _max_dr = 0.1

-- Lens diameter D (mm).
-- Some parameters are specified relative to lens diameter
-- (e.g. aberrations).
adjustable _D_mm = 100

-- Lens object position relative to the reference plane (x=0).
adjustable _P_D    = -5

-- Lens image position relative to the reference plane (x=0).
adjustable _Q_D    = 5


local lensutil = simion.import "lensutil.lua"
local record_result = lensutil.record_result
local record_begin  = lensutil.record_begin
local detect_xcross = lensutil.detect_xcross
local detect_ycross = lensutil.detect_ycross
local move_ray      = lensutil.move_ray
local get_ke        = lensutil.get_ke


--## SECTION: UTILITIES


-- Print parameters used in set of runs.
local function print_run_params()
  local function printf(...) print(string.format(...)) end
  printf("Run Parameters:")
  printf("  VA=%g to %g, VB=%g to %g",
         _VA_min, _VA_max, _VB_min, _VB_max)
  printf("  D=%g mm, P/D=%g, Q/D=%g", _D_mm, _P_D, _Q_D)
  printf("  npoints=%d, max_dr=%g, D_mm=%g",
         _npoints, _max_dr, _D_mm)
end


--## SECTION: SIMION SEGMENTS


-- The following variables are updated by the SIMION segments during the Fly'm.
-- They are used for the calculation of lens properties for the current scan.
local VA, VB = 0,0    -- voltages testing in current run
local yq1             -- particle 1 y position at image plane (mm)
local yq2             -- particle 2 y position at image plane (mm)
local yq3             -- particle 3 y position at image plate (mm)
local yq4             -- particle 4 y position at image plane (mm)
local yp3             -- particle 3 y position at object plane (mm)
local alpha_p1        -- particle 1 angle at object plane (rad)
local alpha_p2        -- particle 2 angle at object plane (rad)
local V1p             -- particle 1 KE at object plane
local V4p             -- particle 4 KE at object plane

-- Main control routine that manages a series of runs to acquire
-- the necessary data for plotting.
function segment.flym()
  sim_trajectory_image_control = 1  -- don't keep trajectories

  -- Output some header data.
  print_run_params()
  record_begin(5, _npoints+1, 'Three Cylinder Zoom Lens', 'VB', 'VA')
  record_result('VB', 'VA', '-M', 'Cs/D', 'Cc/D', 'dr')

  -- Load simplex optimization library. This will be used to
  -- optimize lens voltages such as to minimize beam spot size.
  local SimplexOptimizer = require "simionx.SimplexOptimizer"

  -- For this system, the optimization likely works best when performed
  -- in the domain of log10(voltage) rather than just voltage.
  -- For example, instead of optimizing voltages in the interval
  -- [1/100, 100] V, we optimize log10(voltage) in the interval [-2, 2].
  -- This tends to provide greater detail and control in the low voltage
  -- region.
  local logVA_min = math.log10(_VA_min)
  local logVA_max = math.log10(_VA_max)
  local logVB_min = math.log10(_VB_min)
  local logVB_max = math.log10(_VB_max)

  -- Select `_npoints` points (log10(VA),log10(VB)) at random.
  -- For each point, optimize voltage `VA` to minimize spot size
  -- by starting the optimization at that point.
  for ipoint = 1,_npoints do

    -- Pick random starting point.
    local logVA = rand() * (logVA_max - logVA_min) + logVA_min
    local logVB = rand() * (logVB_max - logVB_min) + logVB_min

    -- Create optimizer initialized at that starting point.
    -- Note that there are infinitely many points (log10(VA),log10(VB))
    -- that minimize beam size, so we constrain one voltage (VB)
    -- at random some random value and optimize the other (VA).
    local maxcalls = 25 -- max number of optimizer iterations.
                        --   increase to increase accuracy.
                        --   decrease to improve speed.
    local step = (logVA_max - logVA_min) / 20  -- initial optimizer step size
    local opt = SimplexOptimizer {
      start = {logVA}, step = {step}, maxcalls=maxcalls}

    -- Rerun simulation using current optimizer voltages until
    -- beam size optimized.
    while true do

      -- Initialize parameters for this run.
      yq1 = nil; yq2 = nil; yq3 = nil; yq4 = nil
      yp3 = nil
      alpha_p1 = nil; alpha_p2 = nil
      V1p = nil; V4p = nil
      logVA = opt:values()  -- next voltage chosen by optimizer
      VA,VB = 10^logVA,10^logVB

      -- Performance trajectory calculation run.  The terminate
      -- routine returns the measured spot radius (dr).
      run()

      -- Feed measured metric to optimization routine and check.
      local dr = math.abs(yq1)
      opt:result(dr)
      if not opt:running() then  -- Is optimization done?
        if dr <= _max_dr and
          VA >= _VA_min and VA <= _VA_max and
          VB >= _VB_min and VB <= _VB_max
        then    -- Did optimization converge?
          -- Compute lens parameters upon focus.
          local M = yq3 / yp3  -- linear magnification
          local Cs = -yq2 / (M * alpha_p2^3) / _D_mm
                       -- Spherical aberration coefficient
                       -- (in terms of lens diameter)
          local Cc = (yq4 - yq1) / (M * alpha_p1 * (V4p - V1p) / V1p) / _D_mm
                       -- Axial chromatic aberration coefficient
                       -- (in terms of lens diameter)
          -- Record the data for this point somewhere.
          record_result(VB,VA, -M, Cs, Cc, dr)
        end
        break -- done or failed to optimize
      end
    end
  end

  print 'done!'
end

-- called exactly once at start of each run.
function segment.initialize_run()
end

-- called on each particle creation inside a PA instance.
function segment.initialize()
  if ion_number == 1 then
    -- Particle #1 starts at the object, on-axis, and is directed
    -- at a small angle (dy/dx > 0) from the +x axis.
    -- This is used to compute the image position (Q).
    assert(ion_py_mm == 0, 'particle 1 expected to start on-axis.')
    alpha_p1 = -ion_vy_mm / ion_vx_mm
    assert(alpha_p1 < 0, 'particle 1 angle expected to be negative')
    V1p = get_ke()
  elseif ion_number == 2 then
    -- Particle #2 is identical to particle #1 but is directed at a much
    -- larger angle.  This is used to compute the spherical aberration
    -- coefficient (Cs).
    assert(ion_py_mm == 0, 'particle 2 expected to start on-axis.')
    alpha_p2 = -ion_vy_mm / ion_vx_mm
    assert(alpha_p2 < 0, 'particle 2 angle expected to be negative')
    assert(alpha_p2 < ion_py_mm,
       'particle 2 angle expected to be larger than that of particle 1.')
  elseif ion_number == 3 then
    -- Particle #3 starts at the object side and is directed
    -- parallel to the axis toward the image (+x).  This is used to
    -- compute linear magnification (M).
    yp3 = ion_py_mm
  elseif ion_number == 4 then
    -- Particle #4 is identical to particle #1 but with an energy offset.
    -- This is used to compute the axial chromatic aberration coefficient (Cc).
    assert(ion_py_mm == 0, 'particle 4 expected to start on-axis.')
    local alpha_p4 = -ion_vy_mm / ion_vx_mm
    --print(alpha_p4 - alpha_p1)
    assert(math.abs(alpha_p4 - alpha_p1) < 1e-15,
           'particles 4 and 1 angles expected to be identical')
    V4p = get_ke()
    assert(V4p ~= V1p, 'particles 1 and 4 energies expected to differ')
  end

  -- Variable object location.
  move_ray(_P_D*_D_mm, ion_px_mm)
end

-- called whenever electrode voltages are needed.
function segment.fast_adjust()
  -- Set lens voltages for current run.
  adj_elect01, adj_elect02, adj_elect03 = _V1, VA, VB
end

-- called on each time-step for each particle in a PA instance.
function segment.other_actions()
  -- Terminate any rays that start moving in the reverse direction.
  if ion_vx_mm < 0 then ion_splat = 1 end

  -- Measure beam
  local Q_mm = _Q_D * _D_mm
  local y = detect_xcross(Q_mm)
  if ion_number == 1 then
    yq1 = yq1 or y
  elseif ion_number == 2 then
    yq2 = yq2 or y
  elseif ion_number == 3 then
    yq3 = yq3 or y
  elseif ion_number == 4 then
    yq4 = yq4 or y
  end
end


--[[
 Footnotes:
 [1] The flym/initialize_run/terminate_run segments are new in SIMION 8.1.0.40.
     See "Workbench Program Extensions in SIMION 8.1" in the supplemental
     documentation (Help menu).
--]]
