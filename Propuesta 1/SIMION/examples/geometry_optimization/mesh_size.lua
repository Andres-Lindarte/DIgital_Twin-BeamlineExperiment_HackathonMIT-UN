--[[
 mesh_size.lua
 Compares trajectory under a variety of PA mesh resolutions
 and Refine convergence objectives.
 
 We could use either a .PA or .PA#/.PA0 array for this.
 If we don't need to alter electrode voltages in each geometry,
 then using a .PA array is more efficient since it avoids
 refining electrode solution arrays and writing to disk, and it
 allows resuming a previous Refine at a lower convergence objective.

 D.Manura, 2012-08-02.
 (c) 2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()

local GEM = simion.import 'gemlib.lua'

-- Parameters for current run.
local dx_mm    -- X cell size (mm)
local dy_mm    -- Y cell size (mm)
local convergence -- Refine convergence objective (V)
local enhanced -- use surface enhancement? (true or false)
local rebuild  -- rebuild PA from GEM file? (true or false)
local ymax, ymin  -- beam Y min and max values at target
local t0       -- calculation starting time (s), for benchmarking

-- Array of results for all runs.
local results = {}

function segment.flym()
  -- Perform series of runs.
  local function doruns()
    rebuild = true
    convergence = 1E-2
    run()
    rebuild = false  -- GEM unchanged
    convergence = 5E-4
    run()
    convergence = 1E-5
    run()
  end
  for i=0,4 do
    dx_mm = 4 / 4^i
    dy_mm = 4 / 4^i
    doruns()
    if i < 4 then
      dx_mm = 4 / 4^i
      dy_mm = 4 / 4^(i+1)
      doruns()
      dx_mm = 4 / 4^(i+1)
      dy_mm = 4 / 4^i
      doruns()
    end
  end
  enhanced = true
  dx_mm = 4
  dy_mm = 4
  convergence = 1E-5
  doruns()

  -- Display summary of all results.
  print('run#', 'yspan', 'dx_mm', 'dy_mm', 'convergence', 'enhanced', 'runtime')
  for i, result in ipairs(results) do
    print(i, result.yspan, result.dx_mm, result.dy_mm, result.convergence, result.enhanced, result.runtime)
  end
end

function segment.initialize_run()
  -- Initialize parameters for current run.
  ymax, ymin = -math.huge, math.huge
  t0 = os.time()

  -- Regenerate PA based on current run parameters.
  local inst = simion.wb.instances[1]
  if rebuild then
    GEM.update_painst_from_gem(inst, 'mesh_size.gem', '', {
      dx_mm = dx_mm, dy_mm = dy_mm, fractional = fractional
    })
  end
  inst.pa:refine{
     convergence=convergence
     --removed:  , skipped_point=rebuild
  }
  -- Note: skipped_point=false sort-of resumes last .PA refine (but sometimes is slower).
  -- Note: If a .PA0 array, do this:  inst.pa:fast_adjust{[1]=1000, [2]=900}
end


function segment.terminate()
  -- Record some metric for each particle splat.
  ymax = math.max(ymax, ion_py_mm)
  ymin = math.min(ymin, ion_py_mm)
end

function segment.terminate_run()
  -- Compute and store results for current run.
  local yspan = ymax - ymin
  local runtime = os.time() - t0
  print(yspan, dx_mm, dy_mm, convergence, enhanced, runtime)
  table.insert(results,
      {yspan=yspan, dx_mm=dx_mm, dy_mm=dy_mm, convergence=convergence, enhanced=enhanced, runtime=runtime})
end
