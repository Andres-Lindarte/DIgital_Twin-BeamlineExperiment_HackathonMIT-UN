--[[
plates_2dp_solve2.lua

This is similar to plates_2dp_solve.lua but builds the PA's entirely
from the PA's API rather than from GEM files.

D.Manura, 2011-12-05
(c) 2011-2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

-- Remove all PA's from RAM.
simion.pas:close()

-- Create electric field PA.
local pa = simion.pas:open()
pa:size(101, 101, 1)
pa.symmetry = '2dplanar'
for xg,yg,zg in pa:points() do
  if xg == 0 then
    pa:point(xg,yg,zg, 1, true)
  elseif xg == pa.nx-1 then
    pa:point(xg,yg,zg, 2, true)
  else
    pa:point(xg,yg,zg, 0, false)
  end
end

-- Create dielectric PA.
-- Note: center of cells is where dielectric is deposited.
local dipa = simion.pas:open()
dipa:size(101-1, 101-1, 1)
dipa.symmetry = '2dplanar'
for xg,yg,zg in dipa:points() do
  local xc,yc,zc = xg+0.5,yg+0.5,zg+0.5  -- center of cells
  dipa:point(xg,yg,zg, xc < 50 and 1 or 3, false)
end
pa:save('plate_2dp.pa#') -- ensure treatment as .pa# style array

-- Refine PA using dielectric PA.
pa:refine {permittivity=dipa, convergence=1E-7}

-- Optionally, for highest electric field accuracy near the dielectric
-- boundary, we may, after refining, convert points along the dielectric
-- boundary to electrode points.  This prevents SIMION from smoothly
-- interpolating the field across the boundary.
--for xg,yg,zg in pa:points() do
--  if xg==50 then pa:electrode(xg,yg,zg, true) end
--end

-- Optionally, prevent prompts to refine PA's without dielectrics.
pa.refinable = false
dipa.refinable = false

-- Save PA's.
pa:save('plate_2dp.pa0')
dipa:save('plate_2dp-dielectric.pa')

-- Optionally, for convenience, load IOB for viewing fields.
simion.command 'plates_2dp.iob'
