-- geometry_optimize.lua
--
-- Simple Lua program for geometry optimization in SIMION.
-- See README.html.
--
-- Author D.Manura, 2006-08,2011-08
-- (c) 2006-2011 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0/8.1)

-- Includes optional SIMION 8.1 features:
--   screen print and running "fly" command in GUI mode.

local HAS_PRINT = simion.print_screen ~= nil

-- Performs a simulation on a single parameterization
-- of the geometry.
-- dx is the axial x-offset in grid units.
-- returns calculated y-offset of outermost splat.
function test(dx)
  -- define global parameter used in GEM file.
  _G.dx = dx

  -- convert GEM file to PA# file.
  local pasharp_filename = "tune.pa#"
  simion.command("gem2pa tune.gem " .. pasharp_filename)

  -- refine PA# file.
  simion.command("refine " .. pasharp_filename)

  -- Fly ions and collect results to _G table.
  simion.command("fly tune.iob")

  print("RESULT: dx=" .. dx .. ", ion_py_gu=" .. _G.result_y)

  return _G.result_y
end


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


-- Simulates all parameterizations.
-- Results are summarized in results.csv.
function test_all()
  -- cleanup any old files.
  os.remove("results.csv")

  local results_file = assert(io.open("results.csv", "w")) -- write mode
  results_file:write("dx, dy\n")

  local html
  if HAS_PRINT then
    html = Html("results.html")
  end

  -- run each test, collecting results to results.csv
  for dx=-40,40,2 do
    local dy = test(dx)
    results_file:write(dx .. ", " .. dy .. "\n")
    results_file:flush()  -- immediately output to disk

    if HAS_PRINT then
      html:add_image('result_' .. dx .. '.png')
      html:add_line('Figure: dx = ' .. dx)
    end
  end

  results_file:close()
  if HAS_PRINT then html:close() end

  print "DONE!  See results.csv."

  -- show results
  os.execute("start notepad results.csv")
  if HAS_PRINT then
    print "See also results.html."
    os.execute("start start results.html") -- or "firefox"
      -- note: need for two "starts" may be a bug in SIMION (TO REVIEW)
  end

end

test_all()  -- do main function

