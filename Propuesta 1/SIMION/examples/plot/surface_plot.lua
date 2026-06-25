--[[
 Simple example of incrementally updating a 2D surface plot.
 Uses plotlib.lua.
 2012-08-18,DM
--]]

local PLOT = simion.import 'plotlib.lua'

local xs = {}; for i=1,10 do xs[#xs+1] = 10+i end
local ys = {}; for i=1,10 do ys[#ys+1] = i/10 end

local plot = PLOT.plot_surface {
  xs = xs, ys = ys,
  xlabel = 'xs',
  ylabel = 'ys',
  title = 'test of surface plot'
}
for xi,x in ipairs(xs) do
for yi,y in ipairs(ys) do
  plot.queued_updates = (yi ~= #ys)  -- improves performance
  plot:update(xi,yi, x*y)
end end
