-- append_chart.lua
--
-- This example demonstrates how to append data to an existing
-- Excel worksheet and chart.  You may want to do this if you
-- are doing a series runs whose data is to be stored in the
-- same Excel file.  The techniques here are particularly
-- useful if you need to shutdown and resume SIMION or your
-- program between data acquisitions.
--
-- To use this example, run this program as Lua batch mode
-- program (e.g. from the "Run Lua Program" button on the
-- SIMION main screen).  If this is the first run, a chart
-- will display with a single series.  Then run this program
-- additional times, and you'll see additional series added
-- to the chart.  You may delete the "test_append.xls" file
-- to start over from scratch.
-- 
-- D.Manura, 2010-09.
-- (c) 2010 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)


-- Gets current working directory of SIMION.
-- This is an absolute path with trailing backslash omitted.
local FSO
local function current_directory()
  FSO = FSO or luacom.CreateObject("Scripting.FileSystemObject")
  return FSO:GetAbsolutePathName("")
end

-- Gets column number of next empty column in worksheet (ws).
-- Examines given row number (rownum).
local function next_empty_column(ws, rownum)
  rownum = rownum or 1
  local colnum = 1
  while ws.Cells(rownum, colnum).Value2 ~= nil do
    colnum = colnum + 1
  end
  return colnum
end

-- Sets up an Excel workbook (create or reuse existing).
local function get_workbook(filename)
  -- Try to attach to an existing Excel process, else create new one.
  local excel = luacom.GetObject("Excel.Application") or
                luacom.CreateObject("Excel.Application")
  excel.Visible = true

  -- Get workbook.
  local wb
  if luacom.CreateObject("Scripting.FileSystemObject"):FileExists(filename) then
    -- Open existing.
    print "Opening existing file..."
    wb = excel.WorkBooks:Open(filename)
  else
    -- Create blank workbook and chart.
    print "Creating new file..."
    wb = excel.WorkBooks:Add()

    -- And add a blank chart.
    local chart = excel.Charts:Add()
    local XYScatter = -4169
    chart.ChartType = XYScatter
    chart.HasTitle=true
    chart.ChartTitle:Characters().Text = "My Chart"
    while chart:SeriesCollection().Count > 0 do -- remove extra series
      chart:SeriesCollection(1):Delete()
    end
  end
  assert(wb)
  return wb, excel
end

-- Add a new series to the workbook's worksheet and chart.
-- Here, we just add some random data for demonstration.
local function add_series(wb)
  local ws = wb.Worksheets(1)
  local colnum = next_empty_column(ws)
  local nrows = 10
  for rownum=1,nrows do
    ws.Cells(rownum,colnum).Value2 = rownum
    ws.Cells(rownum,colnum+1).Value2 = colnum + rand()
  end
  local chart = wb.Charts(1)
  local series = chart:SeriesCollection():NewSeries()
  series.Name = "Series " .. (colnum+1)/2
  series.XValues = ws:Range(ws.Cells(1,colnum), ws.Cells(nrows, colnum))
  series.Values = ws:Range(ws.Cells(1,colnum+1), ws.Cells(nrows,colnum+1))
end

-- Name of Excel file to read/write.
-- An absolute (not relative) path is preferred since Excel's
-- current directly may differ from SIMION's.  Excel also
-- requires backslashes not forward slashes here.
-- Example: local filename = [[c:\temp\test_append.xls]]
local filename = current_directory() .. [[\test_append.xls]]

-- Open or create workbook
local wb, excel = get_workbook(filename)

-- Append data.
add_series(wb)

-- Save it.
excel.DisplayAlerts = false  -- avoid "do you want to replace it?"
wb:SaveAs(filename)
