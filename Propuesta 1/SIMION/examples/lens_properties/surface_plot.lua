--[[
 surface_plot.lua - SIMION Lua workbench user program.
 2D surface plot of beam radius when varying center and exit
 voltages in three cylinder (zoom) lens.

 Note:
 - Using Excel while SIMION is controlling it may cause the
   simulation to fail with an error message.
 - Minimizing the Excel window may improve
   calculation speed as it reduces screen update.
 - This program might not work if "Grouped" mode flying is enabled.
   (ensure "Grouped" is unchecked on the "Particles" tab).
 - For improved speed, set the trajectory computational quality
   ("TQual" on particles tab) to 0.  Default is +3.

 D.Manura, v2013-05-16, 2007-04
 (c) 2007-2013 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()


--## SECTION: ADJUSTABLE AND SYSTEM VARIABLES

-- Electrode numbers corresponding to VA and VB.
adjustable _VA_number = 2
adjustable _VB_number = 3

-- Range of voltages to scan for second (center) element (A).
adjustable _VA_min = 0.1  -- min
adjustable _VA_max = 10   -- max

-- Range of voltages to scan for last (exit) element (B).
adjustable _VB_min = 0.1  -- min
adjustable _VB_max = 10   -- max

-- Range of measured metric (beam diameter) values to plot.
adjustable _metric_min = 0   -- min
adjustable _metric_max = 5  -- max

-- Number of data points to plot in each dimension.
-- Metric is plotted over 2D grid of values.
adjustable _npoints = 21      

-- Lens diameter D (mm).
-- Some parameters are specified relative to lens diameter.
adjustable _D_mm = 100

-- Lens object position relative to the reference plane (x=0).
adjustable _P_D = -5

-- Lens image position relative to the reference plane (x=0).
adjustable _Q_D = 5

-- Whether to plot chart (1=yes, 0=no).
adjustable _use_plot = 1


local lensutil = simion.import 'lensutil.lua'


--## SECTION: UTILITIES


-- Return array of n equidistance numbers from first to last.
local function linrange(first, last, n)
  local t = {}
  for i=1,n do t[i] = first + (last-first)*((i-1)/(n-1)) end
  return t
end

-- Return array of n logarithmically spaced numbers from first to last.
-- Useful for log-scale axes on plots.
local function logrange(first, last, n)
  first = math.log10(first)
  last = math.log10(last)
  local t = {}
  for i=1,n do t[i] = 10^(first + (last-first)*((i-1)/(n-1))) end
  return t
end

-- Print parameters used in set of runs.
local function print_run_params()
  print("Plot:")
  print(string.format("  VA(V%d)=%f to %f", _VA_number, _VA_min, _VA_max))
  print(string.format("  VB(V%d)=%f to %f", _VB_number, _VB_min, _VB_max))
  print(string.format("  metric=%f to %f", 0, 1))
  print(string.format("  npoints=%d", _npoints))
end


--## SECTION: SIMION SEGMENTS


-- The following variables are updated by the SIMION segments during the Fly'm.
local VAs, VBs  -- arrays of voltages A and B to use.
local VA, VB = 0,0  -- voltages A and B being tested in current run
local yq_min, yq_max  -- min and max radial positions on image (Q) plane.
local ndetected -- number of ions detected on image (Q) plane.

function segment.flym()
  sim_trajectory_image_control = 1  -- don't keep trajectories
  sim_trajectory_quality = 0 -- fastest trajectory integration
  
  -- Print run parameters.
  print_run_params()

  -- Create list of voltages to try.
  VAs = logrange(_VA_min, _VA_max, _npoints)
  VBs = logrange(_VB_min, _VB_max, _npoints)

  -- Format labels more nicely.
  local VAs_labels = {}
  local VBs_labels = {}
  for i,v in ipairs(VAs) do VAs_labels[i] = ('%0.2e'):format(v) end
  for i,v in ipairs(VBs) do VBs_labels[i] = ('%0.2e'):format(v) end

  local plot
  if _use_plot ~= 0 then
    -- Create chart to plot on.
    local PLOT = simion.import '../plot/plotlib.lua' -- Load plot library
    plot = PLOT.plot_surface {
      xs=VAs_labels, ys=VBs_labels,
      xlabel='VB(V'.._VB_number..')', ylabel='VA(V'.._VA_number..')', zlabel='diameter (mm)',
      title='Beam Diameter (mm) v.s. Electrode Voltages',
      zmin=_metric_min, zmax=_metric_max}
  end
  

  -- Perform runs.
  -- for ia = 1, #VAs do  for ib = 1, #VBs do
  for ia, ib in lensutil.scatter(#VAs, #VBs) do
    -- Initialize data for this run.
    yq_min, yq_max = math.huge, -math.huge  -- (+/- infinity)
    ndetected = 0
    VA, VB = VAs[ia], VBs[ib]

    -- Perform trajectory calculation run.
    run()

    -- Record beam diameter at image (Q) plane.
    local span = (yq_max - yq_min)
    if _use_plot ~= 0 then
      plot:update(ia,ib, span)
    else
      print(ia,ib, span)
    end
  end
end


-- called exactly once on each run start.
function segment.initialize_run()
end

-- called on each particle creation inside a PA instance.
function segment.initialize()

  assert(ion_py_mm >= 0, 'particle y expected to be non-negative')
  -- Variable object location.
  lensutil.move_ray(_P_D*_D_mm, ion_px_mm)
end

-- called whenever electrode voltages are required.
function segment.fast_adjust()
  -- Adjust electrode voltages.
  adj_elect[_VA_number], adj_elect[_VB_number] = VA, VB
end


-- called on each time-step for each particle in PA instance.
function segment.other_actions()
  -- Rays that start moving in reverse direction are terminated.
  if ion_vx_mm < 0 then ion_splat = 1 end

  -- Measure beam
  local Q_mm = _Q_D * _D_mm
  local y = lensutil.detect_xcross(Q_mm)
  if y and ndetected < ion_number then -- new hit location detected
    -- Store new hit extents.
    ndetected = ion_number
    yq_min = math.min(yq_min, y)
    yq_max = math.max(yq_max, y)
  end
end


--[[
 Footnotes:
 [1] The flym/initialize_run/terminate_run segments are new in SIMION 8.1.0.40.
     See "Workbench Program Extensions in SIMION 8.1" in the supplemental
     documentation (Help menu).
--]]
