--[[
 tilted_plates_batch.lua
 Example of using surface enhancement from a batch mode program.
 Note: this requires SIMION >= 8.1.1.10.
 
 D.Manura, 2012-05,2010
 (c) 2010-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

-- Remove all PA's from RAM.
simion.pas:close()

-- Create PAs (surface enhanced and traditional)
local epa = simion.open_gem('tilted_plates.gem'):to_pa()
local tpa = simion.open_gem('tilted_plates_trad.gem'):to_pa()

-- Ensure these are treated as fast adjustable (.pa# extension).
epa.filename = 'tilted_plates.pa#'
tpa.filename = 'tilted_plates_trad.pa#'

-- Refine
epa:refine{convergence=5e-3}
tpa:refine{convergence=5e-3}

-- Fast adjust.
epa:fast_adjust{[1]=1, [2]=-1}
tpa:fast_adjust{[1]=1, [2]=-1}

-- Now compare the two.

local function norm(x,y,z) return math.sqrt(x^2+y^2+z^2) end

print('Comparison:')
print('x, Delta V (enhanced), Delta V (traditional), V (enhanced)')
local y,z = 20,0
for x=0,22,1 do
  local v_enh = norm(epa:field_vc(x,y,z))
  local v_trad = norm(tpa:field_vc(x,y,z))
  local v_theo = 1/10
  print(("%0.1d, %0.1E, %0.1E, %f"):format(x-11, v_enh-v_theo, v_trad-v_theo, v_enh))
end


-- Note: The gem2pa unloads PA's from RAM, which is currently
-- incompatible with the surface enhancement feature.  So,
-- we don't do this:
--simion.command('gem2pa tilted_plates.gem tiled_plates.pa#')
--simion.command('refine --convergence=5e-3 tilted_plates.pa#')

-- This older method is no longer recommended:
--simion.experimental.gemrefine('tilted_plates.gem',
--  'tilted_plates.pa#', 1e-5) -- convergence level
