-- tof_vs_ion.lua
-- SIMION user program that creates scatterplot in Excel of TOF vs. ion number.
-- This uses the Excel COM interface.
--
-- D.Manura 2010-01,2011-10
-- (c) 2010-2011 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1
simion.workbench_program()


-- Creates excel worksheet on first call.
local excel, wb, ws
local function ensure_excel_open()
  if not excel then
    excel = luacom.CreateObject("Excel.Application")
    excel.Visible = true
    wb = excel.Workbooks:Add()
    ws = wb.Worksheets(1)
  end
end

-- Called on each particle termination in a PA.
local particle_count = 0
function segment.terminate() 
  -- Add data row to excel
  ensure_excel_open()
  particle_count = particle_count + 1
  ws.Cells(particle_count,1).Value2 = ion_number
  ws.Cells(particle_count,2).Value2 = ion_time_of_flight
end

-- Called on run termination.
function segment.terminate_run()
  -- Create Excel chart.
  local chart = excel.Charts:Add()
  chart.ChartType = -4169  -- scatter XY
  local range = ws.UsedRange
  chart:SetSourceData(range, 2)

  chart.HasLegend = 0
  chart.HasTitle = 1
  chart.ChartTitle:Characters().Text = "SIMION TOF v.s. ion number"
  chart.Axes(1,1).HasTitle = 1
  chart.Axes(1,1).AxisTitle:Characters().Text = "ion number"
  chart.Axes(1,2).HasTitle = 1
  chart.Axes(1,2).AxisTitle:Characters().Text = "TOF"
end


--[[
Footnotes:
  The terminate_run segment, new in SIMION 8.1.0.32, is called exactly once
  when the run completes (just after any terminate segment calls).
--]]
