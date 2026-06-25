--[[
 SIMION Lua workbench user program.
 HDA optimization and analysis.
 2012-08-17,2007-04,D.Manura

 In plot mode, minimizing the Excel window may improve
 calculation speed as it reduces screen update.
 Using Excel while SIMION is controlling it may cause the
 simulation to fail with an error message.
--]]

simion.workbench_program()

-- What to do.  Set this to "plot" to plot metric graphically.
-- Set this to "optimize" to optimize metric with simplex optimization
-- routine.  Set this to "" for normal trajectory calculation.
-- You can change this here, or change it on the fly in SIMION
-- by typing for example (mode = "optimize") (without the parenthesis)
-- in the command-bar at the bottom of the SIMION screen.
local mode = mode or "plot"

-- These variables are only used for mode == "plot".
adjustable _VL3_min  = -750    -- lens e(3) min voltage
adjustable _VL3_max  = 7000    -- lens e(3) max voltage
adjustable _VL3_step =  250    -- lens e(3) step voltage
adjustable _VL4_min  = -750    -- lens e(4) min voltage
adjustable _VL4_max  = 5000    -- lens e(4) max voltage
adjustable _VL4_step =  250    -- lens e(4) step voltage
adjustable _plot_beamsize_min = 0  -- beam size for surface plot min color scale
adjustable _plot_beamsize_max = 10 -- beam size for surface plot max color scale
adjustable _use_plot  = 1   -- whether to use plotting library (1=yes, 0=no)
adjustable _nions    = 11   -- set this to number of particles flown

-- These variables are only used for mode == "optimize".
adjustable _opt_VL3_start  =  500   -- starting point for VL3 optimization
adjustable _opt_VL4_start  = 1500   -- starting point for VL4 optimization
adjustable _opt_VL3_step   =  500   -- initial step size for VL3 optimization
adjustable _opt_VL4_step   = 1500   -- initial step size for VL4 optimization

-- called upon first loading IOB
function segment.load()
  -- This program might not work if "Grouped" mode flying is enabled.
  -- Make "Grouped" unchecked on the "Particles" tab.
  sim_grouped = 0

  -- For improved speed, set the trajectory computational quality (T.Qual) to 0.
  sim_trajectory_quality = 0
end

-- Returns true/false whether particle inside detection region.
local function inside_detector()
  return ion_px_mm > 250 and math.abs(ion_py_mm - 155.5)
end

if mode == "plot" then  -- is plot

  -- In this mode, create 2D surface plots on trajectory results
  -- as a function of many combinations of electrode potentials.

  -- Internal variables that persist through the simulation.
  local VL3, VL4      -- electrode voltages used in current run
  local x_min, x_max  -- min and max observed beam x position in current run.
  local hit_count     -- number of detector hits in current run
  local plot, plot2   -- plot objects

  -- This returns an iterator over the integers 1..n, permuted
  -- in such a way that higher powers of 2 are traversed first.
  -- This can be useful for more incremental scans that show
  -- a rough picture before a detailed one.
  local function scatter(n)
    return coroutine.wrap(function()
      local used = {}
      local pow_start = math.floor(math.log(n)/math.log(2))
      for pow=pow_start,0,-1 do
        local step = 2^pow
        for i=1,n,step do
          if not used[i] then
            coroutine.yield(i)
            used[i] = true
          end
        end
      end
    end)
  end  

  -- performs multiple runs.
  function segment.flym()
    -- Print parameters used.
    print("Plot:")
    print(string.format("  VL3=%g to %g step %g", _VL3_min, _VL3_max, _VL3_step))
    print(string.format("  VL4=%g to %g step %g", _VL4_min, _VL4_max, _VL4_step))

    -- Create list of voltages to try.
    local VL3_values = {}
    local VL4_values = {}
    for v=_VL3_min,_VL3_max,_VL3_step do table.insert(VL3_values, v) end
    for v=_VL4_min,_VL4_max,_VL4_step do table.insert(VL4_values, v) end

    -- Initialize plots.
    if _use_plot ~= 0 then
      local PLOT = simion.import '../plot/plotlib.lua' -- Load plot library
      plot = PLOT.plot_surface {xs=VL3_values, ys=VL4_values,
               xlabel='VL3', ylabel='VL4', zlabel='beam diameter (mm)',
               title='Beam Diameter (mm) v.s. Electrode Voltages',
               zmin=_plot_beamsize_min, zmax=_plot_beamsize_max}
      plot2 = PLOT.plot_surface {xs=VL3_values, ys=VL4_values,
               xlabel='VL3', ylabel='VL4', zlabel='hit count',
               title='Number of Particle Hits on Detector v.s. Electrode Voltages',
               zmin=0,zmax=_nions, wb=plot.wb} -- note: reuse same workbook
      plot:activate()  -- show this plot during runs
    end

    -- No need to retain trajectories on disk.
    sim_rerun_flym = 1

    -- Loop through combinations of voltages.
    for i4 in scatter(#VL3_values) do   local v4 = VL3_values[i4]
    for i5,v5 in ipairs(VL4_values) do

      -- Initialize values for this run.
      x_min, x_max = math.huge, -math.huge  -- + and - infinity
      hit_count = 0
      VL3, VL4 = v4, v5

      -- Do run.
      run()

      -- Handle results from run.
      local x_span = x_max - x_min
      if hit_count < _nions then x_span = _plot_beamsize_max end -- ignore partial
      print(string.format("x_span=%f, hits=%d, i4=%d,i5=%d, VL3=%g,VL4=%g",
            x_span, hit_count, i4, i5, VL3, VL4))
      if _use_plot ~= 0 then
        plot.queued_updates  = i5 ~= #VL4_values -- delay plot for performance
        plot2.queued_updates = i5 ~= #VL4_values
        plot:update(i4, i5, x_span)
        plot2:update(i4, i5, hit_count)
      end
    end end

  end
  
  -- Handle each particle splat.
  function segment.terminate()
    if inside_detector() then -- detector hit
      x_min = math.min(x_min, ion_px_mm)
      x_max = math.max(x_max, ion_px_mm)
      hit_count = hit_count + 1
    end
  end

  -- Adjust voltages.
  function segment.fast_adjust()
    -- e03 is Benis VL3 and e04 is Benis VL4 (VL6 is lens entry)
    adj_elect03, adj_elect04 = VL3, VL4
  end

elseif mode == "optimize" then

  -- In this mode, simplex optimize voltages.

  -- Internal variables that persist through the simulation.
  local SimplexOptimizer = require "simionx.SimplexOptimizer"
  local VL3, VL4        -- control voltages defined by optimizer
  local x_min, x_max    -- min and max values of beam x position in current run
  local hit_count       -- number of detector hits in current run

  function segment.flym()
    -- No need to retain trajectories on disk.
    sim_rerun_flym = 1  

    print("Optimization:")
    print(string.format("  VL3 start=%g, step=%g", _opt_VL3_start, _opt_VL3_step))
    print(string.format("  VL4 start=%g, step=%g", _opt_VL4_start, _opt_VL4_step))

    -- Create new optimizer using current adjusted voltages.
    local opt = SimplexOptimizer
                {start={_opt_VL3_start, _opt_VL4_start},
                  step={_opt_VL3_step,  _opt_VL4_step}}

    -- Perform runs until optimizer finishes.
    while opt:running() do
      -- Initialize values for this run.
      x_min, x_max = math.huge, -math.huge  -- + and - infinity
      hit_count = 0
      VL3, VL4 = opt:values()
      -- print('VL3,VL4=', VL3,VL4)

      -- Do run.
      run()
  
      -- Handle results.
      local x_span = x_max - x_min
      if hit_count < _nions then x_span = _plot_beamsize_max end -- ignore partial
      local metric = x_span
      print(string.format("metric=%f, VL3,VL4=%g,%g", metric, VL3, VL4))
      opt:result(metric)
    end

    sim_rerun_flym = 0 -- retain trajectories in last run
    run()
  end

  -- Adjust voltages.
  function segment.fast_adjust()
    adj_elect03, adj_elect04 = VL3, VL4
  end

  -- Handle each particle splat.
  function segment.terminate()
    if inside_detector() then
      -- Used to compute some metric that the optimizer will minimize.
      x_min = math.min(x_min, ion_px_mm)
      x_max = math.max(x_max, ion_px_mm)
      hit_count = hit_count + 1
    end
  end

else  -- is no mode selected

  -- do nothing
  function segment.initialize_run()
    error("invalid mode: "..tostring(mode))
    sim_rerun_flym = 0
  end

end
