--[[
 scatterplot.lua
 SIMION user program that creates scatterplot (phase plot) in Excel.
 This uses the the excellib.lua library to simplify the coding.

 D.Manura 2006-08,2011-10
 (c) 2006-2011 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0/8.1)
--]]
simion.workbench_program()

-- Load plotting library (for Excel or gnuplot)
local PLOT = simion.import 'plotlib.lua'

local particle_count = 0
local dataset = {}

-- SIMION other_actions segment.  Called on every time-step.
function segment.other_actions()
    if ion_splat == 0 then return end -- skip if ion not yet splatted.

    local y = ion_py_mm    -- y position (mm)
    local yprime = atan2(ion_vy_mm, ion_vx_mm) -- angle (rad)

    particle_count = particle_count + 1
    dataset[particle_count] = {y, yprime}
end

-- SIMION terminate segment.  Called on each particle termination.
function segment.terminate_run()
    -- Plot chart.
    PLOT.plot {title='SIMION Phase Plot', xlabel='y', ylabel='yprime', dataset}
end


--[[
Footnotes:
  The terminate_run segment, new in SIMION 8.1.0.32, is called exactly once
  when the run completes (just after any terminate segment calls).
--]]
