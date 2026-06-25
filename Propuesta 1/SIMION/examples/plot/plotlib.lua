--[[
 plotlib.lua.
 Plotting library for SIMION.

 This returns either the excellib.lua or gnuplotlib.lua library depending
 on whether gnuplot and/or Excel is installed and the value of the
 PLOT_LIBRARY global variable.

 You may state a preference for either Excel or gnuplot by setting the
 PLOT_LIBRARY global variable to either 'excel' or 'gnuplot' respectively.
 Leaving it unset (nil) states no preference, and in such case Excel is
 currently preferred if it is installed (though this behavior is subject
 to change in the future).
 
 2012-08-18,D.Manura
 (c) 2011-2012 Scientific Instrument Services, Inc. Licensed SIMION 8.1.
--]]

local function find_lib(filename)
  local function file_exists(filename)
    local fh = io.open(filename)
    if fh then fh:close(); return true else return false end
  end
  if file_exists(filename) then
    return filename
  else
    -- Relative directory path to this file.
    local PATH = debug.getinfo(2).source:gsub('^@(.-)[^/\\]*$', '%1'):gsub('^$', './')
    if file_exists(PATH .. filename) then
      return PATH .. filename
    end
  end
end

local excellib_path   = find_lib 'excellib.lua' or find_lib '../excel/excellib.lua'
local gnuplotlib_path = find_lib 'gnuplotlib.lua' or find_lib '../gnuplot/gnuplotlib.lua'

local EXCEL   = excellib_path   and simion.import(excellib_path)
local GNUPLOT = gnuplotlib_path and simion.import(gnuplotlib_path)

-- Return EXCEL or GNUPLOT library.
if not(PLOT_LIBRARY == nil or PLOT_LIBRARY == 'excel' or PLOT_LIBRARY == 'gnuplot') then
  error('PLOT_LIBRARY variable is set to unrecognized value (' ..
        tostring(PLOT_LIBRARY) .. ').\n'..
        'Valid values are nil, "excel", and "gnuplot".', 3)
end
if (PLOT_LIBRARY or 'excel') == 'excel' and EXCEL and EXCEL.is_excel_installed() then
  return EXCEL
elseif GNUPLOT then
  GNUPLOT.find()
  return GNUPLOT
else
  error('neither excellib.lua or gnuplotlib.lua found', 3)
end
