--[[
 tune.lua

 SIMION user program for tune.pa0.

 D.Manura 2011-11,2006-08
 (c) 2006-2011 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]
 
simion.workbench_program()

-- voltage for central electrode
-- Note: the default value here was found using the _tune example.
adjustable test_voltage = 965.57617

-- number of grid points to step electrode x location per run.
adjustable step_x = 5

-- Utility for HTML file writing.
local Html = function(filename)
  local fh = assert(io.open(filename, "w"))
  fh:write('<html><body>\n')

  local self = {}
  function self:add_image(imgfilename)
    fh:write(('<img src="%s" />\n'):format(imgfilename))
  end
  function self:add_line(text)
    fh:write(('<div>%s</div>\n'):format(text))
  end
  function self:close()
    fh:write('</body></html>\n')
    fh:close()
  end
  return self
end

local result_y

-- Performs a simulation on a single parameterization
-- of the geometry.
-- dx is the axial x-offset in grid units.
-- returns calculated y-offset of outermost splat.
local function test(dx)
  
  -- convert GEM file to PA# file.
  _G.dx = dx  -- pass variable to GEM file.
  local pa = simion.open_gem('tune.gem'):to_pa()
      -- TODO: this function not yet documented
  pa:save('tune.pa#')
  pa:close()

  -- reload in workbench
  simion.wb.instances[1].pa:load('tune.pa#')
  
  -- refine PA# file.
  simion.wb.instances[1].pa:refine()

  -- Fly ions and collect results.
  run()

  print("RESULT: dx=" .. dx .. ", ion_py_gu=" .. result_y)
 
  return result_y
end


-- called on Fly'm and expected to initiate runs by calling `run()`.
function segment.flym()
  -- Simulate all parameterizations.
  -- Results are summarized in results.csv.
  
  -- enable 'output' directory exists
  os.execute("mkdir output")

  -- cleanup any old files.
  os.remove("output/results.csv")

  -- Open output files.
  local results_file = assert(io.open("output/results.csv", "w")) -- write mode
  results_file:write("dx, dy\n")
  local html = Html("output/results.html")

  -- run each test, collecting results to results.csv
  for dx=-40,40,step_x do
    -- Run simulation.
    local dy = test(dx)

    -- Print image of screen to file.
    simion.printer.type = 'png'  -- 'bmp', 'png', 'jpg'
    simion.printer.filename = 'output/result_' .. dx .. '.png'
    simion.printer.scale = 1
    simion.print_screen()
    -- caution: print_screen redraws the screen.  If ion trajectories
    -- are unsaved (i.e. e.g. sim_rerun_flym == 1), they will be lost.

    -- Write data to file.
    results_file:write(dx .. ", " .. dy .. "\n")
    results_file:flush()  -- immediately output to disk
    if html then
      html:add_image('result_' .. dx .. '.png')
      html:add_line('Figure: dx = ' .. dx)
    end
  end

  -- Close output files.
  results_file:close()
  if html then html:close() end

  -- Show results.
  print "DONE!  See output/results.csv."
  os.execute([[start notepad output\results.csv]])
  if html then
    print "See also output/results.html."
    os.execute([[start output\results.html]]) -- or "firefox"
      -- note: need for two "starts" may be a bug in SIMION (TO REVIEW)
  end

end

-- called exactly once on run initialization.
function segment.initialize_run()
  -- Ensure keeping ion trajectories (required for `simion.print_screen`).
  sim_rerun_flym = 0
  sim_trajectory_image_control = 0 -- keep trajectories (when rerun 0)
end

-- called on PA initialization to set voltages.
function segment.init_p_values()
    -- sets central electrode voltage
    adj_elect01 = 1000
    adj_elect02 = test_voltage
end

-- called on each particle splat in PA instance
function segment.terminate()
  -- tune only on ion #6
  if ion_number == 6 then
    -- store results
    result_y = ion_py_gu
  end
end

-- called exactly once on run termination.
function segment.terminate_run()
  -- simion.sleep(1) -- optional pause for easier visualization.

  sim_rerun_flym = 1 -- clears trajectories on rerun
end



--[[
Footnotes:
  The flym/initialize_run/terminate_run segments are new in SIMION 8.1.0.40.
  See "Workbench Program Extensions in SIMION 8.1" in the supplemental documentation
  (Help menu).
--]]
