--[[
  make.lua
  Batch mode Lua program to generate velocity.csv containing velocity data
  and temperature.csv containing tempeature data.  All files are in
  ASCII comma-separated value format in the format expected by the
  simionx.FieldArray library.

  D.Manura, 2009-11.
  (c) 2009 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)
]]

local FieldArray  = require 'simionx.FieldArray'

-- Fill with velocity data and write.
local array = FieldArray {
  symmetry = "planar", mirror = "xy",
  nx = 251, ny = 151, nz = 1
}
array:read(function(x_gu,y_gu,z_gu)   -- Calculate field in array.
  local vx = (150-y_gu)*(150+y_gu) / 100
  return vx,0,0
end)
array:write("velocity.csv")  -- Save to output file.

-- Fill with temperature data and write.
-- Note: FieldArray stores vectors of size 3.  Therefore, even though temperature
-- is a scalar, the function here still must return a vector of size 3 with the
-- second and third elements zero (and ignored by HS1).
local array = FieldArray {
  symmetry = "planar", mirror = "x",
  nx = 251, ny = 301, nz = 1,
  y = -150
  -- note: disable mirror y and resize/shift y accordingly.
}
array:read(function(x_gu,y_gu,z_gu)
  local T = 1  + (150+y_gu) * 1.0
  return T,0,0
end)
array:write("temperature.csv")

-- If SIMION 8.1, write PA versions too.
if simion.pas then
  local pa = simion.pas:open()
  pa.symmetry = "2dplanar[xy]"
  pa:size(251, 151, 1)
  for x_gu,y_gu,z_gu in pa:points() do
    local vx = (150-y_gu)*(150+y_gu) / 100
    pa:potential(x_gu,y_gu,z_gu, vx)
  end
  pa:save("velocity_x.pa")
  pa:close()

  local pa = simion.pas:open()
  pa.symmetry = "2dplanar[x]"
  pa:size(251, 301, 1)
  for x_gu,y_gu,z_gu in pa:points() do
    local T = 1 + y_gu * 1.0
    pa:potential(x_gu,y_gu,z_gu, T)
  end
  pa:save("temperature.pa")
  pa:close()
end

print("done")
