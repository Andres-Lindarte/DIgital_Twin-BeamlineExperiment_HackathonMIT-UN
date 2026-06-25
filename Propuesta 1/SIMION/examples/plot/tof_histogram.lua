--[[
 tof_histogram.lua
 Prints to Log window (and/or plots in Excel) histogram of TOF's.

 D.Manura
 (c) 2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1
--]]

simion.workbench_program()
local STAT = require 'simionx.Statistics'
local PLOT = simion.import 'plotlib.lua'

adjustable binsize = 0.05  -- microseconds

local data = {}

function segment.terminate() 
  table.insert(data, ion_time_of_flight)
end

function segment.terminate_run()
  -- compute histogram.
  local hist = STAT.make_histogram {data=data, binsize=binsize, normalize=false}
  
  -- Print histogram to Log window.
  print('TOF','freq')
  print(hist)
  
  -- Optionally also plot histogram in Excel.
  local result = {xlabel='TOF', ylabel='freq'}
  for i=1,#hist.midpoints do
    table.insert(result, {hist.midpoints[i], hist.frequencies[i]})
  end
  PLOT.plot(result)
end


--[[
Footnotes:
  The terminate_run segment, new in SIMION 8.1.0.32, is called exactly once
  when the run completes (just after any terminate segment calls).
--]]
