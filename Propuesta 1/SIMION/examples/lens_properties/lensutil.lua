--[[
 lensutl.lua
 Utility functions for the Lens Properties examples.

 TODO: One improvement that should be made is to move the plotting
 code into excellib.lua, as well as gnuplotlib.lua (to allow plotting
 from gnuplot which this example currently does not support).
 
 D.Manura, v2013-05-16, 2007-10.
 (c) 2007-2013 Scientific Instrument Services, Inc. (Licensed SIMION 8.0/8.1)
--]]

local M = {}


--## SECTION: PLOTTING AND EXCEL


-- Create new Excel worksheet.
local excel  -- Excel object
local wb     -- Excel workbook
local ws     -- Excel worksheet
local function create_worksheet()
  -- Create Excel object (if not exist).
  -- Note: if you close Excel, type "_G.excel = nil" in the command-bar
  --       to reset.
  if not excel then
    _G.excel = _G.excel or luacom.CreateObject("Excel.Application")
    excel = _G.excel
  end
  -- Create Excel worksheet
  wb = excel.Workbooks:Add()
  ws = wb.Worksheets(1)
  excel.Visible = true
end
M.create_worksheet = create_worksheet

-- Create Excel 2D scattering plot from last created worksheet.
--   ncols - number of columns to plot (positive integer)
--   npoints - number of rows to plot (including heading) (positive integer)
--   title - title for plot (string)
--   xlabel - label for x axis (string)
--   ylabel - label for y axis (string)
local chart
local function plot_chart(ncols, npoints, title, xlabel, ylabel)
  local xlLogarithmic = -4133
  local xlColumns = 2
  local xlXYScatter = -4169

  chart = excel.Charts:Add()
  chart.ChartType = xlXYScatter
  local endletter = string.char(string.byte'A' + ncols - 1)
  chart:SetSourceData(ws:Range("A1", endletter .. npoints), xlColumns)

  chart.HasTitle = 1
  chart.ChartTitle:Characters().Text = title

  chart.Axes(1,1).HasTitle = 1
  chart.Axes(1,1).AxisTitle:Characters().Text = xlabel
  chart.Axes(1,1).ScaleType = xlLogarithmic
  chart.Axes(1,2).HasTitle = 1
  chart.Axes(1,2).AxisTitle:Characters().Text = ylabel
  chart.Axes(1,2).ScaleType = xlLogarithmic
end
M.plot_chart = plot_chart


-- Add data point to worksheet/chart, formatted for 2D surface chart.
local function record_surface(ia,ib, metric)
  print(string.format("index=%d,%d, metric=%g",
                      ia, ib, metric))
  ws.Cells(ia+1, ib+1).Value2 = metric  -- update Excel with data
  wb.Saved = true  -- don't ask to save on close
end
M.record_surface = record_surface

local allowneg = false

-- Begin recording data.
-- The current implementation records data to Excel and plots it.
--   ncols - number of columns to plot (positive integer)
--   npoints - maximum number of rows to plot (including headings) (positive integer)
--   title - chart title (string)
--   xlabel - x axis label (string)
--   ylabel - y axis label (string)
--   allowneg_ - whether to allow (rather than ignore) negative values (Boolean).
--               Note: negative values cause errors in Excel when plotting
--               log plots.
local function record_begin(ncols, npoints, title, xlabel, ylabel, allowneg_)
  allowneg = allowneg_
  -- Create Excel worksheet/chart if it doesn't exist.
  if not chart then
    create_worksheet()
    plot_chart(ncols, npoints, title, xlabel, ylabel)
  end  
end
M.record_begin = record_begin

-- Record result data point.
-- The current implementation below adds the point to a worksheet/chart.
local ix = 0
local function record_result(...)
  -- Output to log window.
  print(ix-1, ...)

  -- Output to Excel worksheet/chart.
  ix=ix+1
  for i=1,select('#', ...) do
    local value = select(i, ...)
    -- omit non-positives, which cause error in log scale plots.
    if not allow_neg and (type(value) == 'number' and value <= 0) then
      value = ''
    end
    -- update Excel with data
    ws.Cells(ix, i).Value2 = value
  end
  wb.Saved = true  -- prevent asking to save on close
end
M.record_result = record_result

-- Adds label to previously recorded data point.
local function record_mark(label)
  local series = chart:SeriesCollection():NewSeries()
  series.XValues = ws:Range('A' .. ix)
  series.Values = ws:Range('B' .. ix)
  series.Name = label
  series.HasDataLabels = true
  local label = series:DataLabels()
  label.ShowSeriesName = true
  label.ShowValue = false
  wb.Saved = true  -- prevent asking to save on close
end
M.record_mark = record_mark


--## SECTION: RAY TRACING


-- Detect x position in which the current particle will cross the y=y0 plane.
-- If the particle is terminating, this value will be extrapolated.
-- Returns nil if it does not cross.
-- Intended to be called from initialize, other_actions, or terminate segments.
local function detect_ycross(y0)
  local dy = ion_time_step * ion_vy_mm
  if ion_py_mm <= y0 and ion_py_mm - dy > y0 or
     ion_py_mm >= y0 and ion_py_mm - dy < y0 or
     ion_splat ~= 0
  then
    local dt = (ion_py_mm - y0) / -ion_vy_mm
    if dt == dt then -- if not "not a number" (NaN)
      local x = ion_px_mm + dt * ion_vx_mm
      return x
    end
  end
  return nil
end
M.detect_ycross = detect_ycross

-- Detect y position in which the current particle will cross the x=x0 plane.
-- If the particle is terminating, this value will be extrapolated.
-- Returns nil if it does not cross.
-- Intended to be called from initialize, other_actions, or terminate segments.
local function detect_xcross(x0)
  local dx = ion_time_step * ion_vx_mm
  if ion_px_mm <= x0 and ion_px_mm - dx > x0 or
     ion_px_mm >= x0 and ion_px_mm - dx < x0 or
     ion_splat ~= 0
  then
    local dt = (ion_px_mm - x0) / -ion_vx_mm
    if dt == dt then -- if not "not a number" (NaN)
      local y = ion_py_mm + dt * ion_vy_mm
      return y
    end
  end
  return nil
end
M.detect_xcross = detect_xcross

-- Move particle x position to x = xnew in a special way.
--
-- Moves particle position to (x,y) = (xnew,yo) given the
-- original position (x,y) = (xo,yo).
--
-- The direction of the particle's velocity will also be rotated in
-- such a way that if the original velocity is directed toward a
-- point (x,y) = (0,yt) in the reference plane, then after moving
-- the velocity continues to be directed toward that point.
--
-- Furthermore, if xnew < xinside (where x < xinside is some
-- field-free region, with x = xinside inside the current array),
-- the particle x position is set to x = xinside and the particle
-- is given y position and velocity as if the particle really
-- originated at x = xnew at some earlier time.
--
-- The typical application for this function is for tracing a ray
-- from a variable object position P in a lens.  We assume a particle
-- is originally defined with constant initial conditions
-- (x,y)=(P_orig,0) and velocity directed toward the point
-- (x,y)=(0,yt) a small distance from the x-axis.  This function
-- moves the particle to (x,y)=(P,0) with velocity still
-- directed at (x,y)=(0,yt).  The x location where the particle
-- later crosses the +X axis is taken as the image position Q of
-- the lens assuming object position Q.
--
-- The use of xinside allows tracing a ray that has a window
-- position outside the current PA.  It allows only the path through
-- the array to be traced (assuming paths outside the array are straight
-- lines through field-free regions).  This is useful because rays
-- outside the PA may be outside of the control of the user program.
-- It may also be useful if there are other optics in those far regions
-- that prevent the regions from being field free, in which case we may
-- still want to obtain local lens properties.
--
-- This function is intended to be called from the initialize segment.
local function move_ray(xnew, xinside)
  assert(ion_pz_mm == 0, "particle z expected to be 0")

  -- Target (x,y) position where the ray is directed toward.
  local xt = 0
  local yt = ion_py_mm + (ion_vy_mm / ion_vx_mm) * (xt - ion_px_mm)

  local old_angle = math.atan(ion_vy_mm / ion_vx_mm)
  local new_angle = math.atan((yt - ion_py_mm) / (xt - xnew))
  ion_vx_mm, ion_vy_mm, ion_vz_mm
    = elevation_rotate((new_angle - old_angle) * 180 / math.pi,
      ion_vx_mm, ion_vy_mm, ion_vz_mm)
  ion_px_mm = xnew

  -- move particle by delta time required to reach x=xinside.
  if xnew < xinside then
    local dt = (xinside - ion_px_mm) / ion_vx_mm
    ion_px_mm = ion_px_mm + ion_vx_mm * dt
    ion_py_mm = ion_py_mm + ion_vy_mm * dt
    ion_pz_mm = ion_pz_mm + ion_vz_mm * dt -- normally vz is 0 though
  end
end
M.move_ray = move_ray

-- Get kinetic energy of current particle.
-- Intended to be called from initialize, other_actions, or terminate segments.
local function get_ke()
  local speed = math.sqrt(ion_vx_mm^2+ion_vy_mm^2+ion_vz_mm^2)
  return speed_to_ke(speed, ion_mass)
end
M.get_ke = get_ke


-- This returns an iterator over all combinations of
-- integers 1..n and 1..m, permuted
-- in such a way that higher powers of 2 are traversed first.
-- This can be useful for more incremental surface plot
-- scans that show a rough picture before a detailed one.
-- m defaults to 1 if omitted.
function M.scatter(n, m)
  m = m or 1
  return coroutine.wrap(function()
    local used = {}
    local pow_start = math.floor(math.log(math.max(n,m))/math.log(2))
    for pow=pow_start,0,-1 do
      local step = 2^pow
      for j=1,m,step do
      for i=1,n,step do
        local key = j*n .. i
        if not used[key] then
          coroutine.yield(i,j)
          used[key] = true
         end
      end end
    end
  end)
end

return M
