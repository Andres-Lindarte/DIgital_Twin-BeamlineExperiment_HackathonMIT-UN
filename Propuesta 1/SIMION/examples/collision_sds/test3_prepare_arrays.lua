--[[
 test3_prepare_array.lua

 This program will build the gas flow PAs for use in test3.iob.
 This program should be run via the "Run Lua Program" button on the
 SIMION main screen prior to loading test3.iob.
 (However, this program has already been run for you, so you don't
 need to run it yourself unless you want to change the gas
 flows.)

 Warning: the P,T,v values used below are only examples for
 demonstration.  They do not necessarily make sense from a
 Navier-Stokes steady-state flow dynamics perspective.
--]]

local function fpressure(x,y,z) -- Torr
  if x > 20 then
    return 100 + 660 * ((x-20)/80)
  else
    return 100
  end
end
local function ftemperature(x,y,z) -- K
  return 300
end
local function fvelocity(x,y,z) -- m/s
  local vx = math.max(20-math.abs(y), 0)/5 * math.max(40-math.abs(x-50), 0)/40
  local vy = 5*y/100 * (x > 50 and 1 or -1)
  local vz = 0
  return vx,vy,vz
end

local pa = simion.pas:open'test.pa0'

-- Build arrays.
-- Build pressure array (Torr)
local pressure = simion.pas:open()
pressure:size(pa:size())
pressure.symmetry = pa.symmetry
for xi,yi,zi in pressure:points() do
  pressure:potential(xi,yi,zi, fpressure(xi,yi,zi))
end
-- Build temperature array (K)
local temperature = simion.pas:open()
temperature:size(pa:size())
temperature.symmetry = pa.symmetry
for xi,yi,zi in temperature:points() do
  temperature:potential(xi,yi,zi, ftemperature(xi,yi,zi))
end
-- Build velocity component arrays (m/s)
local vx = simion.pas:open()
vx:size(pa:size())
vx.symmetry = pa.symmetry
local vy = simion.pas:open()
vy:size(pa:size())
vy.symmetry = pa.symmetry
local vz = simion.pas:open()
vz:size(pa:size())
vz.symmetry = pa.symmetry
for xi,yi,zi in vx:points() do
  local vxval,vyval,vzval = fvelocity(xi,yi,zi)
  vx:potential(xi,yi,zi, vxval)
  vy:potential(xi,yi,zi, vyval)
  vz:potential(xi,yi,zi, vzval)
end

-- Prevent SIMION (>=8.1.0.40) prompting to refine these arrays on IOB load.
pressure.refinable = false
temperature.refinable = false
vx.refinable = false
vy.refinable = false
vz.refinable = false

pressure:save'test3_p.pa'
temperature:save'test3_t.pa'
vx:save'test3_vx.pa'
vy:save'test3_vy.pa'
vz:save'test3_vz.pa'


--[[
-- Optionally also save in old text format (SIMION 8.0 compatible)
local AL = simion.import 'arraylib.lua'
AL.save_pa_as_text('vx_defs.dat', vx)
AL.save_pa_as_text('vy_defs.dat', vy)
AL.save_pa_as_text('vz_defs.dat', vz)
AL.save_pa_as_text('p_defs.dat', pressure)
AL.save_pa_as_text('t_defs.dat', temperature)
AL.--]]
