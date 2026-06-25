--[[
 excellib.lua
 Library for simplified recording and plotting of data in Excel.
 This should be simpler to use that the underlying Excel API.
 
 Example:
   local EX = simion.import 'excellib.lua'
   local t = {{10, 20}, {20,25}, {30,27}, title = 'testing'}
   local plot = EX.plot(t)

   simion.sleep(5) -- wait five seconds before updating again
   t[1][2] = 30    -- change data
   plot:update_data(t)
 
 v2013-02-11, 2008-05-10, D.Manura
 (c) 2008-2013 Scientific Instrument Services, Inc. Licensed SIMION 8.1.
--]]

local EXCEL = {}
local Plot = {}

--[[
  Returns true/false whether Excel is installed.
--]]
function EXCEL.is_excel_installed()
  return luacom.CLSIDfromProgID "Excel.Application" ~= nil
end


--[[
  Returns an Excel object.
  Keeps at most one Excel object open at a time (_G.excel).
  Raises on error.
--]]
function EXCEL.get_excel()
  if not EXCEL.is_excel_installed() then
    error("Excel does not appear installed.")
  end
  -- If Excel object exists but doesn't work, perhaps the Excel process
  -- was prematurely terminated.  If so, release the Excel object.
  if _G.excel and not pcall(function() local _ = _G.excel.Visible end) then
    _G.excel = nil
  end
  -- Attempt to create new Excel object if it doesn't exist.
  _G.excel = _G.excel or luacom.CreateObject("Excel.Application")
  if not _G.excel then
    error("Could not create Excel object.")
  end
  return _G.excel
end


local CHART_TYPES = {}
CHART_TYPES.scatter = -4169     -- scatterplot (xlXYScatter)
CHART_TYPES.scatter_lines = 74  -- scatterplot with connecting lines (xlXYScatterLines)
CHART_TYPES.bar_vertical = 51   -- vertical bar chart (xlColumnClustered)
CHART_TYPES.area = 1            -- area chart (xlArea)

local function check_label(name, value)
  -- http://stackoverflow.com/questions/13182413/vba-code-error-chart-title-in-excel
  if #value > 255 then
    error(('Excel chart %s cannot exceed 255 characters (%d given).')
          :format(name, #value))
  end
end

--[[
  Plots data from table t in Excel.
  
  t is normally an array of rows of column values.  Alternately, t
  may be an array of arrays of rows of column values.
  t may optionally also contain these fields:

    header - array of column headers.
    title - title for plot.  Defaults to none if omitted.
    xlabel - x label for plot.  Defaults to t.header[1] if omitted.
    ylabel - y label for plot.  Defaults to t.header[2] if omitted.
    chart_type - any chart type name string in CHART_TYPES above
                   (defaults to 'scatter')
    lines - if true and chart_type is nil then chart_type is set to 'scatter_lines'

  Returns a "plot" object, which may subsequently be used to call
  plot:update_data.  It also has "wb" (Excel Workbook Object),
  "ws" (Excel Worksheet object)and "chart" (Excel Chart object) fields.

  Examples:

    -- Plot points (1,2) and (4,5)
    EXCEL.plot {{1,2}, {4,5}}

    -- Plot with additional parameters
    EXCEL.plot {header={'time', 'speed'},
                title='my plot', xlabel='t', ylabel='s', lines=true,
                {1,2}, {4,5}}

    -- Plot two data series having same X values.
    -- First column is X.  Second and third columns are Y for each series.
    EXCEL.plot {{1,2,3}, {4,5,6}}

    -- Plot two data series having possibly different X values.
    -- Two independent sets of data:
    -- First column is X.  Second column is Y.
    EXCEL.plot {{{1,2},{4,5}}, {{2,6},{3,7}}}
--]]
function EXCEL.plot(t)
  local chart_type = t.chart_type

  -- Compatibility with older versions of this library.
  if t.lines then
    assert(chart_type == nil)
    chart_type = 'scatter_lines'
  end

  local excel = EXCEL.get_excel()

  -- Set up worksheet.
  excel.Visible = true
  local wb = excel.Workbooks:Add()
  local ws = wb.Worksheets(1)

  -- Set up chart.  
  local chart = excel.Charts:Add()
  -- Set chart type.
  if chart_type and not CHART_TYPES[chart_type] then
    error("undefined chart type " .. tostring(chart_type), 2)
  end
  chart_type = chart_type or 'scatter'
  chart.ChartType = CHART_TYPES[chart_type]

  local plot = setmetatable({wb=wb, ws=ws, chart=chart}, {__index = Plot})
  
  -- Normalize table.
  local datasets = (t[1] and t[1][1] and type(t[1][1]) ~= 'table') and {t} or t
  
  -- For each dataset...
  local icol = 1
  for _,dataset in ipairs(datasets) do
    -- number of rows and columns in data.
    local nrows = #dataset
    local ncols = #(dataset.header or dataset[1])
  
    -- Transfer header labels and data to Excel.
    if dataset.header then
      for i=1,#dataset.header do
        check_label('header', dataset.header[i])
      end
      ws:Range(ws.Cells(1,icol), ws.Cells(1, icol+ncols-1)).Value2 = dataset.header
    end

    if nrows > 0 then
      -- Define chart data sources.
      for i=1,ncols-1 do
        local series = chart.SeriesCollection(chart):NewSeries()
        if not ws.Cells(2,icol).Value2 and tonumber(excel.Version) < 12 then
          ws.Cells(2,icol).Value2 = 0
          -- workaround for old Excel 2002 [v10] and 2003 [v11]
          -- "Unable to set the Values property of the Series class"
        end
        series.Name =    ws:Range(ws.Cells(1, icol+i), ws.Cells(1, icol+i))
        series.XValues = ws:Range(ws.Cells(2, icol),   ws.Cells(2+nrows, icol))
        series.Values  = ws:Range(ws.Cells(2, icol+i), ws.Cells(2+nrows, icol+i))
      end
    end

    icol = icol + ncols
  end

  plot:update_data(t)

  -- Define chart options.
  if t.title then
    check_label('title', t.title)
    chart.HasTitle = true
    chart.ChartTitle:Characters().Text = t.title
  end
  local xlabel = t.xlabel or t.header and t.header[1]
  if xlabel then
    check_label('xlabel', xlabel)
    chart.Axes(1,1).HasTitle = true
    chart.Axes(1,1).AxisTitle:Characters().Text = xlabel
  end
  local ylabel = t.ylabel or t.header and t.header[2]
  if ylabel then
    check_label('ylabel', ylabel)
    chart.Axes(1,2).HasTitle = true
    chart.Axes(1,2).AxisTitle:Characters().Text = ylabel
  end
  -- In bar chart, ensure tick marks in center of bars
  if chart_type == 'bar_vertical' or chart_type == 'area' then
    local xlCategory = 1
    chart:Axes(xlCategory).AxisBetweenCategories = false
  end

  wb.Saved = true  -- prevent asking to save.
  
  return plot
end

--[[
  Updates a plot previously returned by the `plot` function.
  Data table `t` is in the same format as in `plot`, except that
  only row/column data values are used.
--]]
function Plot:update_data(t)
  local ws = self.ws
  
  -- Normalize table.
  local datasets = (t[1] and t[1][1] and type(t[1][1]) ~= 'table') and {t} or t

  -- For each dataset...
  local icol = 1
  for _,dataset in ipairs(datasets) do
    -- number or rows and columns in data.
    -- number of rows and columns in data.
    local nrows = #dataset
    local ncols = #(dataset.header or dataset[1])
  
    -- Transfer header labels and data to Excel.
    --OLD: ws:Range(ws.Cells(2,1), ws.Cells(nrows+1, ncols)).Value2 = t
    if nrows > 0 then
      -- workaround for LuaCOM bug http://simion.com/issue/495.2
      -- is to transfer data in chunks.
      -- OLD: ws:Range(ws.Cells(2,icol), ws.Cells(nrows+1, icol+ncols-1)).Value2
      --       = dataset
      local i=1
      while i <= nrows do
        local copy = {}
        for j=1,500 do copy[j] = dataset[i + j - 1] end
        ws:Range(ws.Cells(1+i,icol), ws.Cells(1+i+#copy-1, icol+ncols-1)).Value2 = copy
        i = i + 500
      end
    end

    icol = icol + ncols
  end -- dataset
 
  local wb = ws.Parent
  wb.Saved = true  -- prevent asking to save.
end

--[[
  update plot title
--]]
function Plot:title(title)
  check_label('title', title)
  self.chart.HasTitle = true
  self.chart.ChartTitle:Characters().Text = title
  self.wb.Saved = true -- prevent asking to save above change
end

--[[
  Plots data as 2D surface plot in Excel.

  xs - array of row names (strings or numbers)
  ys - array of column names (strings or numbers)
  xlabel - x axis label (string, optional)
  ylabel - y axis label (string, optional)
  zlabel - z axis label (string, optional)
  title - chart title (string, optional)
  zmin - minimum value for z axis (affects color scale) (number, optional)
  zmax - maximum value for z axis (affects color scale) (number, optional)
  color - use color (true) or use black/white (false) color scale.
          (optional, defaults to true)
  wb - Excel workbook to place chart in (optional, defaults to new workbook).
  
  Example:
    local plot = EXCEL.plot_surface {
         xs={100,200,300},ys={500,550,600},
         xlabel='V1',ylabel='V2',zlabel='beam size',zmin=0,zmax=10}
    for i=1,3 do for j=1,3 do
      plot:update(i,j, i*j)
    end end
--]]
function EXCEL.plot_surface(t)
  local xs = assert(t.xs)
  local ys = assert(t.ys)
  local xlabel = t.xlabel or 'x'; check_label('xlabel', xlabel)
  local ylabel = t.ylabel or 'y'; check_label('ylabel', ylabel)
  local zlabel = t.zlabel or 'z'; check_label('zlabel', zlabel)
  local zmin = t.zmin or nil
  local zmax = t.zmax or nil
  local color = t.color == nil and true or t.color
  local wb_old = t.wb or nil  -- optionally reuse excel workbook object

  local plot = {}
  plot._queue = {}
  plot.queued_updates = false -- whether updates are queued
  
  -- Sets value at index [i,j] to given value.
  -- Updates will be queued (e.g. for performance) if plot.queue_updates is true.
  function plot:update(i, j, value)
    table.insert(plot._queue, {i=i,j=j,value=value})
    if not plot.queued_updates then
      local disable = #plot._queue > 1
      if disable then plot.excel.ScreenUpdating = false end
      for i=#plot._queue,1,-1 do
        local data = plot._queue[i]
        self.ws.Cells(data.i+1, data.j+1).Value2 = data.value  -- update Excel with data
        table.remove(plot._queue)
      end
      self.wb.Saved = true -- prevent asking to save above change
      if disable then plot.excel.ScreenUpdating = true end
    end
  end
  
  -- Changes plot title.
  function plot:title(title)
    check_label('title', title)
    self.chart.HasTitle = true
    self.chart.ChartTitle:Characters().Text = title
    self.wb.Saved = true -- prevent asking to save above change
  end
  
  -- Brings plot to top if multiple plots exist.
  function plot:activate()
    self.chart:Activate()
  end

  -- util
  local function clamp(x, xmin, xmax)
    return math.max(math.min(x, xmax), xmin)
  end
  local function round(x) return math.floor(x + 0.5) end
  
  -- Maps value f to (R,G,B) color-space, where f,R,G,B in [0,1].
  -- This follows the path (0,0,1)[blue],(0,1,1)[cyan],(0,1,0)[green],
  -- (1,1,0)[yellow],(1,0,0)[red] in (R,G,B) space as f goes from 0 to 1.
  local function rgb_colorscale(f)
    f = f * (4 - 1E-12)
    local r = clamp(f-2, 0, 1)
    local g = clamp(2-math.abs(f-2), 0, 1)
    local b = clamp(2-f, 0, 1)
    return r,g,b
  end
  local function rgb_grayscale(f)
    local r = clamp(f, 0, 1)
    local g = clamp(f, 0, 1)
    local b = clamp(f, 0, 1)
    return r,g,b
  end
  
  -- Create Excel object (if not exist).
  plot.excel = EXCEL.get_excel()
  local excel = plot.excel

  excel.Visible = true
  excel.ScreenUpdating = false
  
  -- Create Excel worksheet
  excel.SheetsInNewWorkbook = 1
  if wb_old then
    plot.wb = wb_old
    plot.ws = plot.wb.Worksheets:Add()
  else
    plot.wb = excel.Workbooks:Add()   -- excel workbook
    plot.ws = plot.wb.Worksheets(1)   -- excel worksheet
  end
  
  -- Set data labels.
  for i=1,#xs do plot.ws.Cells(i+1, 1).Value2 = xs[i] end
  for i=1,#ys do plot.ws.Cells(1, i+1).Value2 = ys[i] end
  
  local is2d = #xs > 1 and #ys > 1
  
  -- Create chart.
  plot.chart = excel.Charts:Add()
  local range = plot.ws.UsedRange
  local xlColumns = 2
  local xlRows = 1
  plot.chart:SetSourceData(range, xlColumns)
  plot.chart.ChartType =
    (#xs==1 or #ys==1) and 51 -- 1D bar vertical xlColumnClustered
                       or 85  -- 2D surface top view, xlSurfaceTopView

  -- Configure axes.
  -- note: excel 2D surface plot doesn't support 1D data
  plot.chart.Axes(1,1).HasTitle = 1
  plot.chart.Axes(1,1).AxisTitle:Characters().Text = #xs~=1 and xlabel or ylabel
  plot.chart.Axes(1,2).HasTitle = 1
  plot.chart.Axes(1,2).AxisTitle:Characters().Text = zlabel
  if is2d then
    plot.chart.Axes(1,3).HasTitle = 1
    plot.chart.Axes(1,3).AxisTitle:Characters().Text = ylabel
  end
  -- Set Z range.
  if zmin and zmax then
    local ncolors = 10
    plot.chart.Axes(1,2).MinimumScale = zmin
    plot.chart.Axes(1,2).MaximumScale = zmax
    local TOL = 1.0000000000001 -- avoid color problems at zmax due to numerical roundoff.
    plot.chart.Axes(1,2).MajorUnit = (zmax - zmin) / ncolors * TOL

    -- Set color scale for Z range.
    -- Remove all this if you want the standard Excel rainbow palette.
    excel.ScreenUpdating = true -- required for updating LegendEntries
    local ncolors = plot.chart.Legend:LegendEntries().Count
    excel.ScreenUpdating = false
    ncolors = math.min(ncolors, 56)
    for i=1,ncolors do
      local f = math.min((i-1)/(ncolors-1), 1)  -- weight [0,1]
      local r,g,b = (color and rgb_colorscale or rgb_grayscale)(f)
      r,g,b = round(r * 255), round(g * 255), round(b * 255)
      local c = r + g*256 + b*256^2 -- red-green-blue components
      plot.wb:setColors(i,c)
    end
    for i=1,ncolors do
      plot.chart.Legend:LegendEntries(i).LegendKey.Interior:setColorIndex(i);
    end
  end

  -- note: can't do this before creating surface plot
  plot.ws.Cells(1, 1).Value2 = xlabel .. "\\" .. ylabel
  
  if t.title then
    plot:title(t.title)
  end

  excel.ScreenUpdating = true
  plot.wb.Saved = true -- prevent asking to save above change
  
  return plot
end
  

return EXCEL
