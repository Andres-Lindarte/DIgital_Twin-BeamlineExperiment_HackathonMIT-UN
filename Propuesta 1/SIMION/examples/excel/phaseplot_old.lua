-- scatterplot.lua
-- SIMION user program that creates scatterplot (phase plot) in Excel.
-- This uses the Excel COM interface.
--
-- D.Manura 2006-08
-- (c) 2006 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)
simion.workbench_program()

-- Connect to Excel and create worksheet.
local excel = luacom.CreateObject("Excel.Application")
excel.Visible = true
local wb = excel.Workbooks:Add()
local ws = wb.Worksheets(1)
local particle_count = 0

-- SIMION other_actions segment.  Called on every time-step.
function segment.other_actions()
    if ion_splat == 0 then return end -- skip if ion not yet splatted.

    local y = ion_py_mm    -- y position (mm)
    local yprime = atan2(ion_vy_mm, ion_vx_mm) -- angle (rad)

    particle_count = particle_count + 1
    ws.Cells(particle_count,1).Value2 = y
    ws.Cells(particle_count,2).Value2 = yprime
end

-- SIMION terminate segment.  Called on each particle termination.
function segment.terminate()
    if ion_number ~= 1 then return end -- only do this once

    -- Create Excel chart.
    local chart = excel.Charts:Add()
    chart.ChartType = -4169  -- scatter XY
    local range = ws.UsedRange
    chart:SetSourceData(range, 2)

    -- Set labels / formatting.
    --chart.PlotArea.Interior.Color = 0xffffff  -- white (RGB)
    chart.HasLegend = 0
    chart.HasTitle = 1
    chart.ChartTitle:Characters().Text = "SIMION Phase Plot"
    chart.Axes(1,1).HasTitle = 1
    chart.Axes(1,1).AxisTitle:Characters().Text = "y"
    chart.Axes(1,2).HasTitle = 1
    chart.Axes(1,2).AxisTitle:Characters().Text = "yprime"
end
