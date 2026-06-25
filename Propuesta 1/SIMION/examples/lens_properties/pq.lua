--[[
 pq.lua - SIMION Lua workbench user program.
 Generates P-Q curve for a two-element lens.

 Image position (P) and object position (Q) relative to the reference
 plane (x=0) are computed and plotted for combinations of
 lens voltage ratio (V2/V1) and lens linear magnification (M).

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

 D.Manura, 2011-11-30,2007-10.
 (c) 2007-2011 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()


--## SECTION: ADJUSTABLE AND SYSTEM VARIABLES


-- Entrance electrode voltage.
-- This is held constant during the scan.
-- Note: voltage levels given below must be expressed relative to the zero
--   of particle KE.  That is, 0V corresponds to a potential at which the
--   particle would be at rest.  For example, if a 5 eV electron originates
--   in the entrance lens, then the voltages must be referenced such that the
--   entrance lens is measured at 5V (or -(5/2)V for a particle of +2 charge).
adjustable _V1 = 1

-- Range of V2/V1 values to scan, where V2 is exit electrode voltage.
adjustable _V21_min = 2     -- min bound
adjustable _V21_max = 10    -- max bound
adjustable _V21_npoints=10  -- number of points in range

-- Range of linear magnification (M) values to scan.
-- By convention these are negative.
adjustable _M_min = -6.0    -- min bound
adjustable _M_max = -0.2    -- max bound
adjustable _M_npoints = 10  -- number of points in range

-- Lens diameter D (mm).
-- Some parameters are specified relative to lens diameter.
adjustable _D_mm = 100

-- Range of object positions to scan.
-- Values in this range are used by the optimizer for initial
-- guesses of P values corresponding the the V2/V1 and M values
-- currently being scanned.
-- This range should be large enough to contain all values of P/D
-- expected from the V2/V1 and M ranges, but it also should not
-- not be too large such that P values selected from this range
-- would make the optimizer struggle or fail.
-- Acceptable values here can be determined by trial-an-error.
adjustable _P_min_D = -100  -- min bound (units of D)
adjustable _P_max_D = -1    -- max bound (units of D)


local lensutil = simion.import 'lensutil.lua'
local record_result = lensutil.record_result
local record_begin  = lensutil.record_begin
local record_mark   = lensutil.record_mark
local detect_xcross = lensutil.detect_xcross
local detect_ycross = lensutil.detect_ycross
local move_ray      = lensutil.move_ray


--## SECTION: UTILITIES


-- Print parameters used in run set.
local function print_run_params()
  local function printf(...) print(string.format(...)) end
  printf('Run Parameters:')
  printf('  D = %g mm', _D_mm)
  printf('  V2/V1 = %g to %g with %d points', _V21_min, _V21_max, _V21_npoints)
  printf('  M = %g to %g with %d points',     _M_min,   _M_max,   _M_npoints)
  printf('  P/D = %g to %g', _P_min_D, _P_max_D)
end


--## SECTION: SIMION SEGMENTS


-- The following variables are updated by the SIMION segments during the Fly'm.
-- They are used for the calculation of lens properties for the current scan.
local V21 -- V2/V1 set-point
local M   -- linear magnification set-point for optimizer
local r1  -- initial radius (mm) of ray #2 -- used for M calculation
local P   -- object position (mm) set-point
local Q   -- image position (mm) actual measurement
local M_measured -- linear magnification actual measurement


-- Main control routine that manages a series of runs to acquire
-- the necessary data for plotting.
function segment.flym()
  sim_trajectory_image_control = 1 -- don't keep trajectories

  -- Output some header data.
  print_run_params()
  record_begin(2, _V21_npoints * _M_npoints + 1,
               'P-Q Curve for Two Cylinder Lens', '-P/D', 'Q/D')
  record_result('-P/D', 'Q/D', 'V2/V1', '-M')

  -- Load simplex optimization library. This will be used to
  -- optimize lens voltages such as to achieve lens property goals
  -- (magnification M here).
  local SimplexOptimizer = require 'simionx.SimplexOptimizer'

  -- For this system, the optimization likely works best when performed
  -- in the domain of log values.  This tends to provide greater detail
  -- and control in the small value regions.
  local logV21_min  = math.log10(_V21_min)
  local logV21_max  = math.log10(_V21_max)
  local lognM_max   = math.log10(-_M_min)
  local lognM_min   = math.log10(-_M_max)
  local lognP_max_D = math.log10(-_P_min_D)
  local lognP_min_D = math.log10(-_P_max_D)

  -- Build list of evaluation points.
  local V21s = {}; for i = 1,_V21_npoints do
    V21s[i] = 10^(((i-1)/(_V21_npoints-1)) * (logV21_max - logV21_min)
                  + logV21_min)
  end
  local Ms = {}; for i = 1,_M_npoints do
    Ms[i] = -10^(((i-1)/(_V21_npoints-1)) * (lognM_max - lognM_min)
                 + lognM_min)
  end

  -- Locate center points.  Data labels in graphs will be plotted on them.
  local V21_center = V21s[math.floor((1 + #V21s)/2)]
  local M_center   = Ms[math.floor((1 + #Ms)/2)]

  -- For each combination of V2/V1 and M parameters, analyze lens properties.
  for _,_V21 in ipairs(V21s) do
  for _,_M in ipairs(Ms) do

    -- Set V2/V1 and M parameters for current analysis.
    V21 = _V21
    M = _M

    -- Retry optimizer with new random starting point until optimizer
    -- provides solution.  Retries can be needed because the optimizer
    -- only finds local minima.  The surface being optimized is even
    -- undefined in certain regions.
    local max_retries = 50
    local is_optimized = false
    for n=1,max_retries do

      -- Optimize P subject to the optimization condition
      -- that M_measured = M.

      -- Select random starting point P for optimizer.
      local lognP_D = (lognP_max_D + lognP_min_D) * rand() + lognP_min_D

      -- Create optimizer initialized at that starting point.
      local maxcalls = 25 -- max number of optimizer iterations.
                          --   increase to increase accuracy.
                          --   decrease to improve speed.
      local step = (lognP_max_D - lognP_min_D) / 20
                          -- initial optimizer step size
      local opt = SimplexOptimizer {
        start = {lognP_D}, step = {step}, maxcalls=maxcalls}
  
      -- Rerun simulation using current voltage given by optimizer until
      -- optimization completes or fails.
      while true do

        -- Initialize parameters for this run.
        lognP_D = opt:values()
        P = -10^lognP_D * _D_mm
        Q = nil           -- to be measured
        M_measured = nil  -- to be measured
        -- print('optimizer iteration:', 'P/D=', P/_D_mm, 'V2/V1=', V21, 'M=', M)
  
        -- Perform trajectory calcualtion .run.
        -- The terminate routine sets Q and M_measured.
        run()

        print('optimizing:', 'V2/V1=', V21, 'M=', M,
              'P/D=', P/_D_mm, 'Q/D=', Q and Q/_D_mm, 'M_measured=',M_measured)
  
        if not M_measured then
          print('Beam did not cross Q. Skipping this optimization.')
          break -- optimization failed
        end
  
        -- Feed measured metric to optimization routine and check.
        local metric = math.abs(M_measured - M)
        opt:result(metric)
        if not opt:running() then  -- Is optimization done?
          if metric < math.abs(M) * 0.1 then   -- Did optimization converge?
            is_optimized = true
            -- Record the data for this point somewhere.
            record_result(-P/_D_mm, Q/_D_mm, V21, -M)
            if V21 == V21_center then
              record_mark('-M=' .. string.format('%0.3g', M))
            end
            if M == M_center then
              record_mark('V2/V1=' .. string.format('%0.3g', V21))
            end
            break -- done
          else
            print('Optimizer not successful.  Skipping this optimization.')
            break -- optimization failed
          end
        end
        local lognPnext_D = opt:values()
        local Pnext_D = -10^lognPnext_D
        if Pnext_D < _P_min_D or Pnext_D > _P_max_D then
          print('P/D out of range. Skipping this optimization.', Pnext_D)
          break -- optimization failed
        end
      end -- for each optimizer iteration

      if is_optimized then break end  -- done
    end -- for each initial P trial

    if not is_optimized then
      print 'Solution not found for current parameter set. Skipping.'
    end
  end end -- for each V2/V1 and M

  print 'done!'
end

-- called exactly once at start of each run.
function segment.initialize_run()
end

-- called on each particle creation inside PA instance
function segment.initialize()
  if ion_number == 1 then
    -- Particle #1 starts on the axis at the object position (P)
    -- and is directed at a small angle to the axis.  The x position
    -- where it crosses the axis is taken as the object position (Q).
    assert(ion_px_mm < 0, 'particle 1 x expected to be negative')
    move_ray(P, ion_px_mm)  -- Variable object location.
  elseif ion_number == 2 then
    -- Particle #2 starts at some small offset r1 away from
    -- the axes with initial velocity parallel to the axis.
    -- It crosses the image plane (x=Q) at some offset r2 from the axis.
    -- The linear magnification M is taken to be r2/r1.
    -- Initialize particle.
    assert(ion_py_mm >  0, 'particle 2 y expected to be positive')
    assert(ion_pz_mm == 0, 'particle 2 z expected to be 0')
    assert(ion_vy_mm == 0, 'particle 2 y velocity expected to be 0')
    assert(ion_vz_mm == 0, 'particle 2 z velocity expected to be 0')
    r1 = ion_py_mm
  end
  -- print('test particle', ion_px_mm, ion_py_mm, ion_vx_mm, ion_vy_mm)
end

-- called whenever electrode voltage is needed.
function segment.fast_adjust()
  -- Set lens voltages for current run.
  adj_elect01, adj_elect02 = _V1, V21 * _V1
end

-- called on every time-step for every particle inside PA instance.
function segment.other_actions()
  -- Terminate any rays that start moving in the reverse direction.
  if ion_vx_mm < 0 then ion_splat = 1 end

  -- Measure Q and M
  local x = detect_ycross(0)
  if ion_number == 1 and x and Q == nil then
    Q = x
    if Q < P then Q = nil end  -- (not converge)
  elseif ion_number == 2 and Q then
    local y = detect_xcross(Q)
    if y and not M_measured then
      assert(ion_vy_mm < 0)
      local r2 = y
      M_measured = r2/r1
    end
  end
end

-- called exactly once at end of each run.
function segment.terminate_run()
end


--[[
 Footnotes:
 [1] The flym/initialize_run/terminate_run segments are new in SIMION 8.1.0.40.
     See "Workbench Program Extensions in SIMION 8.1" in the supplemental
     documentation (Help menu).
--]]
