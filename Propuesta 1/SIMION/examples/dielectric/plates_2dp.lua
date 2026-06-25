--[[
plates_2dp.lua

This is a simple example of solving the electric field with a dielectric
between two parallel plate electrodes.  This demonstrates invoking Refine
(pa:refine), upon clicking Fly'm, passing it a dielectric PA.
This also demonstrates the case where the electric potential array is fast adjustable.

D.Manura, 2012-01-05.
(c) 2011-2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

simion.workbench_program()

local dipa = simion.wb.instances[1].pa -- dielectric constants
local pa   = simion.wb.instances[2].pa -- electric potential

-- Refine convergence objective (V).
adjustable convergence = 1E-5

-- Called by SIMION on Fly'm.
function segment.flym()
  -- Refine. [*1]
  --removed: pa:refine{permittivity=dipa, convergence=convergence}
  local v1,v2 = pa:potential(0,0,0), pa:potential(100,0,0)
  pa:load'plates_2dp.pa#'
  pa:refine{permittivity=dipa, convergence=convergence}
  pa:fast_adjust{[1]=v1, [2]=v2}
  
  -- Optionally, for highest electric field accuracy near the dielectric
  -- boundary, we may, after refining, convert points along the dielectric
  -- boundary to electrode points.  This prevents SIMION from smoothly
  -- interpolating the field across the boundary.
  -- However, make sure this doesn't exist if you ever refine the PA again.
  --for xg,yg,zg in pa:points() do
  --  if xg==50 then pa:electrode(xg,yg,zg, true) end
  --end
  
  -- Update display.
  simion.redraw_screen()
end

--[[
 Footnotes:

 [*1] A simple refine call on the .PA0 file, as shown in the commented-out
 line will properly update the current field.  However, if you subsequently
 attempt to fast adjust, the field will not be updated properly.  Refining the
 .PA0 array will not refine the other electrode solution files.  With dielectric
 effects, all electrode solutions are affected and should be re-refined.
 Refining the .PA# array (accomplished via the above pa:load'plates_2dp.pa#'
 prior to the pa:refine), will update all solution arrays.  However, this
 load will reset any adjustable potentials to zero, so to avoid losing those
 values, we store the current values and restore them after refine.
 This process possibly should be simplified in a future update to SIMION.
--]]
