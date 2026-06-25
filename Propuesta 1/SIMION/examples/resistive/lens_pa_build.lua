--[[
 lens_build.lua - generates lens.pa.

 This is an example of building a basic PA file with
 resistive electrodes.
 
 D.Manura, 2012-09
 (c) 2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

-- convergence objective to use.
local convergence = 1E-7

-- Utility functions.
local function write_file(filename, data)
  local fh = assert(io.open(filename, 'wb'))
  fh:write(data)
  fh:close()
end
local function clip(x, xmin, xmax)
  return math.max(math.min(x, xmax), xmin)
end

simion.pas:close()  -- remove all PA's from RAM.

-- Generates initial .pa file.
local gem = [[
  pa_define(251,56,1, cylindrical,, electrostatic)
  e(1) { fill { within { box(50,50,100,55) } } }
  e(2) { fill { within { box(150,50,200,55) } } }
]]
write_file('lens.gem', gem)
--[[
simion.command'gem2pa lens.gem lens.pa'
local pa = simion.pas:open'lens.pa'
--]]
local pa = simion.open_gem('lens.gem'):to_pa()

-- Replace electrode potentials with gradients.
for x,y,z in pa:points() do
  local v, e = pa:point(x,y,z)
  if e then
    if v == 1 then
      pa:potential(x,y,z, clip((x-50)/50, 0,1)*10)
    elseif v == 2 then
      pa:potential(x,y,z, clip((x-150)/50, 0,1)*10)
    end
  end
end

-- Refine PA and save.
pa:refine{convergence=convergence}
pa:save()

print 'DONE'
