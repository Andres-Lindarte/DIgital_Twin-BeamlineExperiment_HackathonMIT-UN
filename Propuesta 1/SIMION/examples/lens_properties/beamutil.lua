--[[
 beamutil.lua
 utility functions for computing beam characteristics
 D.Manura, 2007-11-30,2011-11
 (c) 2007-2011 Scientific Instrument Services, Inc. (Licensed SIMION 8.0/8.1)
--]]

local M = {}

local lensutil = simion.import 'lensutil.lua'
local record_begin  = lensutil.record_begin
local record_result = lensutil.record_result

-- This function is called iteratively from an other_actions segment,
-- passing current ion number (nion) and position (x,y,z).
-- Data is stored for later use.
local data = {}
function M.record_beam(nion, x,y,z)
  local d = data[nion]
  if not d then
    d = {x={},y={},z={}}
    data[nion] = d
  end
  local pos = #d.x+1
  d.x[pos] = x
  d.y[pos] = y
  d.z[pos] = z
end

-- Clears recorded data from memory.
function M.clear()
  data = {}
end

-- find locates lowest index n such that
-- t[n] <= x, or 1 if none found. TODO-check.
local function helper(t, x, n1, n2)
  if n1 == n2 then
    return n1
  else
    local n = math.ceil((n1 + n2) * 0.5)
    if x >= t[n] then
      return helper(t, x, n, n2)
    else
      return helper(t, x, n1, n-1)
    end
  end
end
local function find(t, x)
  return helper(t, x, 1, #t)
end

-- compute average of numbers in array t.
local function average(t)
  local s = 0
  for n=1,#t do s = s + t[n] end
  return s / #t
end

-- Given beam data stored previously by record_beam,
-- compute size of disc containing beam at given x position.
-- algorithm could be improved since result is approximate.
function M.get_disc(x)
  local ys,zs = {},{}
  for _,d in pairs(data) do
    local n = find(d.x, x)
    local _,y,z = d.x[n], d.y[n], d.z[n] -- TODO - improve by interpolation?
    ys[#ys+1] = y
    zs[#zs+1] = z
  end

  local ya = average(ys)
  local za = average(zs)
  local r2max = 0
  for n=1,#ys do
    local r2 = (ys[n] - ya)^2 + (zs[n] - za)^2
    if r2 > r2max then r2max = r2 end
  end
  local rmax = math.sqrt(r2max)
  return ya,za,rmax
end

-- Given beam data stored previously by record_beam,
-- compute disc of least confusion in given x range
-- xmin to xmax with step xstep.
function M.get_min_disc(xmin,xmax,xstep)
  local xc,yc,zc,rc = nil,nil,nil,math.huge
  xstep = xstep or 1
  for x=xmin,xmax,xstep do
    local ya,za,rmax = M.get_disc(x)
    --print(x,ya,za,rmax)
    if rmax < rc then
      xc,yc,zc,rc = x,ya,za,rmax
    end
  end
  return xc,yc,zc,rc
end

-- utility function that appends code to SIMION segment,
-- preserving any previous code defined.
local function append_segment(name, func)
  local old_func = segment[name]
  local new_func
  if old_func then
    new_func = function()
      old_func()
      func()
    end
  else
    new_func = func
  end
  segment[name] = new_func
end

function M.plot_beam_width(xmin, xmax, xstep)
  local n = (xmax - xmin) / xstep + 1

  record_begin(2,n+1, 'Beam Width', 'x', 'r', true)
  record_result('x', 'r')
  for i=1,n do
    local x = xmin + xstep * (i-1)
    local ya,za,rmax = M.get_disc(x)
    record_result(x, rmax)
  end
end

-- Enable disc of least confusion calculation mode.
-- calculates on ion numbers n1 to n2.
function M.enable_confusion_mode(n1,n2, xmin,xmax,xstep, is_plot)
  append_segment('other_actions', function()
    if ion_number >= n1 and ion_number <= n2 then
      M.record_beam(ion_number, ion_px_mm,ion_py_mm,ion_pz_mm)
    end
  end)
  append_segment('terminate_run', function()
    local x,y,z,rmax = M.get_min_disc(xmin,xmax,xstep)
    print('min disc confusion:','x=',x,'y=',y,'z=',z,'rmax=',rmax)

    if is_plot then
      M.plot_beam_width(xmin,xmax,xstep)
    end
  end)
end


return M


--[[
 Footnotes:
 [1] The flym/initialize_run/terminate_run segments are new in SIMION 8.1.0.40.
     See "Workbench Program Extensions in SIMION 8.1" in the supplemental
     documentation (Help menu).
--]]
