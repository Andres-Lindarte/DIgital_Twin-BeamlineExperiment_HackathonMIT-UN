--[[
 twisted_rods_build.lua -
 Builds PA of complex curved octupole shape, with bends, twists,
 shears, and variable radii.
 This design is not intended to be practical but rather merely to
 show techniques for defining such geometries involving
 curved rods, pipes, and wires.
 Some aspects of this geometry are not easilly defined via GEM files.
 Click "Run Lua Program" on the SIMION main screen to run this.
 
 D.Manura, 2012-09
 (c) 2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

local function clip(v, vmin, vmax)  -- clip v within range [vmin, vmax]
  return math.max(math.min(v, vmax), vmin)
end

simion.pas:close()  -- remove all PA's from RAM.

-- Define PA object
local pa = simion.pas:open()
pa:size(141,81,61)
pa.symmetry = '3dplanar'
pa.dx_mm, pa.dy_mm, pa.dz_mm = 1,1,1
pa:fill { function(x,y,z)
  for i=1,8 do  -- each rod
    -- Translate coordinates of test point (x,y,z) for 90 degree bend.
    -- Each point after bend is first mapped back to plane y = ym.
    -- Each point inside bend region is mapped back to plane x = xm.
    -- Remove this block of code to eliminate the bend.
    local ym = 60; local xm = 100
    if x > xm then -- region inside or after bend.
      y = math.min(y, ym)  -- map after to y=ym
      x, y = xm, ym - math.sqrt((x-xm)^2 + (ym-y)^2) -- map inside to x=xm
    end

    -- Rod parameters as a function of x.
    local R0 = 20 - clip(x-70,0,20)/2
    local rrod = 5 - clip(x-70,0,20)/10
    local theta = (i/8 + clip(x-30,0,30)/120) * (2*math.pi)
    local cost = math.cos(theta)
    local sint = math.sin(theta)
    local y0 = 30 + clip(x-10,0,10)/2 + R0 * cost
    local z0 = 30 + R0 * sint

    -- Fill circular rod.
    if (y-y0)^2 + (z-z0)^2 <= rrod^2 then
      local v = (i%2)+1
      return v, true
    end
  end
end, surface='fractional' }  -- optionally with surface enhancement

pa:save('twisted_rods.pa#')
