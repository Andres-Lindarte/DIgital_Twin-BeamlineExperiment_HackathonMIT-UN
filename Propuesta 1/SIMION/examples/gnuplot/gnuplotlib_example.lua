--[[
 gnuplotlib_example.lua
 This is a simple example demonstrating how to use the gnuplotlib.lua library
 to make a plot in gnuplot.
 D.Manura, 2011-09
--]]

local PLOT = simion.import 'gnuplotlib.lua'

-- A few examples you may enable:
--plot {{0,1,6}, {1,2,4}, {2,4,2}, {3,6,1}}
--plot {{{1,2},{4,5}}, {{2,6},{3,7}}, xlabel='position', ylabel='velocity'}

-- This function generates some random data points for us to see.
local function make_data()
  local data = {}
  for i=1,5000 do
    local x = 2*rand()-1
    local y = 2*rand()-1
    if x^2 + y^2 < 1 then table.insert(data, {x,y}) end
  end
  return data
end

-- Plot the data points.
local myplot = PLOT.plot {
    header={'time', 'x'},
    title='my plot', xlabel='t', ylabel='s', title='foo1',
    make_data()}

-- Update the graph a few times with new data points.
for i=1,5 do
  myplot:title(os.date())
  myplot:update_data{make_data()}
  simion.sleep(1)
end
