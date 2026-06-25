-- Lua program that creates a scatter plot in Excel
-- D.Manura. 2006-08

local excel = luacom.CreateObject("Excel.Application")
excel.Visible = true
local wb = excel.Workbooks:Add()
local ws = wb.Worksheets(1)
for row=1,100 do
   ws.Cells(row,1).Value2 = math.random()
   ws.Cells(row,2).Value2 = math.random()
end

local chart = excel.Charts:Add()
chart.ChartType = -4169  -- scatter XY
chart.HasLegend = 0
local range = ws.UsedRange
chart:SetSourceData(range, 2)

