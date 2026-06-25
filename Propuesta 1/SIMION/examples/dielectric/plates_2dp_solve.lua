--[[
plates_2dp_solve.lua

This builds and refines the PA's for the plates_2dp.iob example.  This
file is not actually necessary since plates_2dp.iob will do this all for
you on Fly'm.  Nevertheless, this file provides an example of doing this from a
batch mode program, if you prefer.

Solves the electric field of two ideal infinite parallel electrode plates
(100 V at x=0 and 0 V at x=100mm) with a dielectric filling the region x < 50 mm.

D.Manura, 2011-12-05.
(c) 2011-2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

-- Remove all PA's from RAM.
simion.pas:close()

-- Convert GEM's to PA's.
simion.command 'gem2pa plates_2dp.gem plates_2dp.pa#'
simion.command 'gem2pa plates_2dp-dielectric.gem plates_2dp-dielectric.pa'

-- Load PA's and refine.
local pa = simion.pas:open 'plates_2dp.pa#'
local dipa = simion.pas:open 'plates_2dp-dielectric.pa'
pa:refine{permittivity=dipa, convergence=1E-7}

-- Optionally, prevent subsequent refining without dielectric PA.
pa.refinable = false
dipa.refinable = false

-- Optionally, for highest electric field accuracy near the dielectric
-- boundary, we may, after refining, convert points along the dielectric
-- boundary to electrode points.  This prevents SIMION from smoothly
-- interpolating the field across the boundary.
--for xg,yg,zg in pa:points() do
--  if xg==50 then pa:electrode(xg,yg,zg, true) end
--end

-- Save PA.
pa:save()
dipa:save()

-- Optionally, for convenience, load IOB for viewing fields.
simion.command 'plates_2dp.iob'
