--[[
 sc_build.lua.

 Batch mode program to build
 2D cylindrical symmetry spherical capacitor,
 WITH surface enhancements.
 
 This is an alternative approach to using a GEM file (sc.gem).
--]]


simion.pas:close()
local pa = simion.pas:open()
pa:size(130,130,1)
pa.symmetry = '2dcylindrical[x]'

pa:fill { function(x,y,z)
  local r = math.sqrt(x^2+y^2+z^2)
  if r <= 80 then
    return 500.0000, true
  elseif r >= 120 then
    return -333.3333, true
  else
    return 0, false
  end
end, surface='fractional'}

pa:refine { convergence=1e-5 }
pa:save'sc.pa'
