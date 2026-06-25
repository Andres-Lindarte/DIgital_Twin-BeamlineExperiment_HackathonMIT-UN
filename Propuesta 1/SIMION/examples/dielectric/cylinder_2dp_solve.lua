--[[
cylinder_2dp_solve.lua

This builds and refines the PA's for the cylinder_2dp.iob example.  This
file is not actually necessary since cylinder_2dp.iob will do this all for
you on Fly'm.  Nevertheless, this file provides an example of doing this from a
batch mode program, if you prefer.

This solves the electric field of an infinite cylinder of dielectric
material inside an otherwise uniform field (approximated by two infinite
parallel electrode plates at a sufficient distance away).
(Based on Griffiths 4.22)

D.Manura, 2011-12-05.
(c) 2011-2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

-- Remove all PA's from RAM
simion.pas:close()

-- Convert GEM's to PA's.
simion.command 'gem2pa cylinder_2dp.gem cylinder_2dp.pa'
simion.command 'gem2pa cylinder_2dp-dielectric.gem cylinder_2dp-dielectric.pa'

-- Load PA's and refine.
local pa = simion.pas:open 'cylinder_2dp.pa'
local dipa = simion.pas:open 'cylinder_2dp-dielectric.pa'
pa:refine{permittivity=dipa, convergence=1E-7}

-- Optionally, prevent subsequent refining without dielectric PA.
pa.refinable = false
dipa.refinable = false; dipa:save()

-- Save PA.
pa:save()

-- Optionally, for convenience, load IOB for viewing.
simion.command 'cylinder_2dp.iob'
