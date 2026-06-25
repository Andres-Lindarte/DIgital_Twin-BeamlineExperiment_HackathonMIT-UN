--[[
 zoom_afocal.lua - SIMION Lua workbench user program.
 Five-cylinder afocal zoom lens.

 For a five-element lens with defined lens voltages V1 and V5,
 plots lens voltages (V2, V3, V4) required to obtain a range of
 linear magnifications, assuming either (1) lens is operated
 in afocal mode or (2) V3/V1 = sqrt(V5/V1).

 This is a quite instructive example of SIMION user programming,
 illustrating real-time Excel plotting, simplex optimization,
 and use of Lua coroutines to simplify automation of a series
 of runs.

 By default, this example plots results in Excel, but it can be
 easily customized to send results to some other program (e.g. maybe
 you have some other plotting program under Linux or have a
 custom routine of your own).  Just replace the record_*
 functions with your own implementation.

 Comments:
 - Using Excel while SIMION is controlling it may cause the
   simulation to fail with an error message.
 - This program might not work if "Grouped" mode flying is enabled.
   (ensure "Grouped" is unchecked on the "Particles" tab).

 D.Manura, 2011-11-30, 2007-10.
 (c) 2007-2011 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]
simion.workbench_program()


--## SECTION: ADJUSTABLE AND SYSTEM VARIABLES


-- Mode of operation.
--   1 = afocal zoom lens, finding V2,V3,V4
--   2 = zoom lens with V3/V1 = sqrt(V5/V1)
adjustable _mode = 1

-- Range of linear magnification (M) values to scan.
adjustable _M_min = -2      -- min bound
adjustable _M_max = -1/2    -- max bound

-- V1, which is first electrode voltage.
adjustable _V1 = 1

-- Range of V2/V1 values to scan, and starting value for optimizer,
-- where V2 is second electrode voltage.
adjustable _V21_min = 1/2    -- min bound
adjustable _V21_max = 50     -- max bound
adjustable _V21_start = 10   -- starting value

-- Range of V3/V1 values to scan, and starting value for optimizer,
-- where V3 is third electrode voltage
adjustable _V31_min = 1/2    -- min bound
adjustable _V31_max = 50     -- max bound
adjustable _V31_start = 1    -- starting value

-- Range of V4/V1 values to scan, and starting value for optimzer,
-- where V4 is fourth electrode voltage
adjustable _V41_min = 1/2    -- min bound
adjustable _V41_max = 50     -- max bound
adjustable _V41_start = 10   -- starting value

-- V5/V1, where V5 is fifth electrode voltage
adjustable _V51 = 1

-- Number of data points to test.
-- This is the upper bound (actual number plotted may be smaller).
adjustable _npoints = 100

-- Lens diameter D (mm).
-- Some parameters are specified relative to lens diameter
adjustable _D_mm = 100

-- Lens object position relative to the reference plane (x=0).
adjustable _P_D = -3.2

-- Lens image position relative to the reference plane (x=0).
adjustable _Q_D = 3.2  -- (units of D)


local lensutil = simion.import "lensutil.lua"
local record_result = lensutil.record_result
local record_begin  = lensutil.record_begin
local detect_xcross = lensutil.detect_xcross
local detect_ycross = lensutil.detect_ycross
local move_ray      = lensutil.move_ray


--## SECTION: UTILITIES


-- Print parameters used in run set.
local function print_run_params()
  local function printf(...) print(string.format(...)) end
  printf("Run Parameters:")
  printf("  D = %g mm", _D_mm)
  printf("  npoints = %d", _npoints)
  printf("  V1 = %g", _V1)
  printf("  V2/V1 start = %d", _V21_start)
  printf("  V3/V1 start = %d", _V31_start)
  printf("  V4/V1 start = %d", _V41_start)
  printf("  V5/V1 = %g", _V51)
  printf("  M = %g to %g", _M_min, _M_max)
end


--## SECTION: SIMION SEGMENTS

-- The following variables are updated by the SIMION segments during
-- the Fly'm.  They are used for the calculation of lens properties
-- for the current scan.
local yp1      -- particle 1 y position at object plane
local yq1      -- particle 1 y position at image plane
local alpha_q1 -- particle 1 angle at image plane
local yq2      -- particle 2 y position at image plane

local M        -- set-point linear magnification for current run
local V21      -- set-point V2/V1 for current run
local V31      -- set-point V3/V1 for current run
local V41      -- set-point V4/V1 for current run

-- Main control routine that manages a series of runs to acquire
-- the necessary data for plotting.
function segment.flym()
  sim_trajectory_image_control = 1  -- don't keep trajectories

  -- Output some header data.
  print_run_params()
  record_begin(4, _npoints + 1, 'Five Element Afocal Zoom Lens Voltages',
               'M', 'Potential')
  record_result(
    '-M', 'V21', 'V31', 'V41', '-M_measured', '|alpha_q1|', '|yq2|',
    'metric', 'metric1', 'metric2', 'metric3')

  -- Load simplex optimization library.
  -- (used to optimize voltages for desired linear and angular
  -- magnifications)
  local SimplexOptimizer = require "simionx.SimplexOptimizer"

  -- For this system, the optimization likely works best when performed
  -- in the domain of log values.  This tends to provide greater detail
  -- and control in the small value regions.
  local lognM_min = math.log10(-_M_max)
  local lognM_max = math.log10(-_M_min)
  local logV21_min = math.log10(_V21_min)
  local logV21_max = math.log10(_V21_max)
  if _mode == 2 then
    _V31_min = math.sqrt(_V51)
    _V31_max = _V31_min
  end
  local logV31_min = math.log10(_V31_min)
  local logV31_max = math.log10(_V31_max)
  local logV41_min = math.log10(_V41_min)
  local logV41_max = math.log10(_V41_max)

  -- Select `_npoints` points (log10(VA),log10(VB)) at random.
  -- For each point, optimize voltage `VA` to minimize spot size
  -- by starting the optimization at that point.
  for ipoint = 1,_npoints do

    -- Pick random starting point.
    local lognM = rand() * (lognM_max - lognM_min) + lognM_min
    --local logV21 = rand() * (logV21_max - logV21_min) + logV21_min
    --local logV31 = rand() * (logV31_max - logV31_min) + logV31_min
    --local logV41 = rand() * (logV41_max - logV41_min) + logV41_min
    local logV21 = math.log10(_V21_start)
    local logV31 = math.log10(_V31_start)
    local logV41 = math.log10(_V41_start)

    -- Create optimizer initialized at that starting point.
    local maxcalls = 1000
        -- max number of optimizer iterations.
        --   increase to increase accuracy; decrease to improve speed.
        --   This must be fairly large due to slow convergence
        --   given the number of dimensions optimized.
    local stepV21 = (logV21_max - logV21_min) / 20
    local stepV31 = (logV31_max - logV31_min) / 20
    if _mode == 2 then stepV31 = 0 end  -- constant V3/V1
    local stepV41 = (logV41_max - logV41_min) / 20
        -- initial optimizer step size
    local opt = SimplexOptimizer {
      start = {logV21, logV31, logV41}, step = {stepV21, stepV31, stepV41},
      maxcalls=maxcalls}

    -- Rerun simulation using current optimizer voltages until
    -- beam size optimized.
    while true do

      -- Initialize parameters for this run.
      logV21,logV31,logV41 = opt:values()  -- next voltage chosen by optimizer
      V21,V31,V41 = 10^logV21,10^logV31,10^logV41
      M = -10^lognM

      -- Performance trajectory calculation run.  The terminate
      -- routine returns the measured spot radius (dr).
      run()

      if not yq1 or not yq2 then -- not converged
        break
      end

      local M1_measured = yq1 / yp1   -- linear magnification

      -- Compute a single metric for optimization routine to minimize.
      -- The metric taken as the sum of (3) other individual metrics.
      -- The individual metrics represent parameters we want to
      -- minimize.  Each individual metric is defined to be
      -- non-negative and scaled so that the parameter is accepted
      -- the metric is less than 1.
      -- Improved convergence may be found by adjusting the relative
      -- weightings of individual metrics (e.g. by squaring a metric).
      local metric1, metric2, metric3
      if _mode == 1 then
        metric1 = math.abs(100 * (M1_measured / M - 1))^2 
        metric2 = math.abs(1000 * alpha_q1) 
        metric3 = math.abs(100 * yq2)^2
      else
        metric1 = math.abs(100 * (M1_measured / M - 1))
        metric2 = 0
        metric3 = math.abs(100 * yq2)
      end
      local metric = metric1 + metric2 + metric3

      local function format(x) return string.format('%0.1e', x) end
      print('optimization:', 'metric=', format(metric), '(',
            format(metric1), format(metric2), format(metric3), ')')

      -- Feed measured metric to optimization routine and check.
      opt:result(metric)
      if metric < 1 or not opt:running() then  -- Is optimization done?
        if metric < 1 then    -- Did optimization converge?
          -- Record the data for this point somewhere.
          record_result(
            -M, V21, V31, V41,
            -M1_measured, math.abs(alpha_q1), math.abs(yq2),
            metric, metric1, metric1, metric3)
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

function segment.initialize()
  if ion_number == 1 then
    -- Particle #1 starts at the image plane, off-axis, with
    -- direction parallel to the axis.
    -- The y position at which it crosses the image plane
    -- determines the linear magnification, and the angle
    -- it crosses at is zero if lens is operated in afocal mode.
    yp1 = ion_py_mm
    yq1 = nil
    alpha_q1 = nil
  elseif ion_number == 2 then
    -- Particle #2 starts at the image plane, on-axis, with
    -- direction at a small angle to the axis.
    -- The x position and angle at which it crosses the axis
    -- determines the image plane.
    move_ray(_P_D*_D_mm, ion_px_mm)  -- Variable object location.
    yq2 = nil
  end
end

-- The SIMION fast_adjust segment sets the fast adjustable electrode
-- voltages seen by the current particle in the current time-step.
function segment.fast_adjust()
  -- Set lens voltages for current run.
  adj_elect01, adj_elect02, adj_elect03, adj_elect04, adj_elect05
    = _V1, V21*_V1, V31*_V1, V41*_V1, _V51*_V1
end

-- The SIMION other_actions segment handles each particle time step.
function segment.other_actions()
  if ion_number == 1 then
    local y = detect_xcross(_Q_D * _D_mm)
    if y and not yq1 then
      yq1 = ion_py_mm
      alpha_q1 = ion_vy_mm / ion_vx_mm
    end
  elseif ion_number == 2 then
    local y = detect_xcross(_Q_D * _D_mm)
    if y and not yq2 then
      yq2 = ion_py_mm
    end
  end
end



--[[
 Footnotes:
 [1] The flym/initialize_run/terminate_run segments are new in SIMION 8.1.0.40.
     See "Workbench Program Extensions in SIMION 8.1" in the supplemental
     documentation (Help menu).
--]]
