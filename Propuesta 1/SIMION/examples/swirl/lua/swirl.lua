-- swirl.lua
-- Generates a swirl-like SIMION potential array
--   (like a ribbon wrapped around a cylinder)
--
-- D.Manura, Scientific Instrument Services, Inc.


assert(simion.pas, 'This example requires SIMION 8.1.')


print("Generating swirl.pa# file....\n")

local PI = math.pi

-- create new potential array
local pa = simion.pas:open()
pa:size(100, 100, 100)

-- iterate over all points
for x,y,z in pa:points() do
    -- compute polar coordinates
    local dx = x - 50
    local dy = y - 50
    local radius = sqrt(dx * dx + dy * dy)

    if dx == 0 and dy == 0 then -- atan2 would fail on this
        theta = 0
    else
        theta = math.atan2(dy, dx)  -- -PI..PI
    end

    -- this is what generates the rotation along the axis.
    local omega = PI + theta + z/5.0
    -- wrap around omega to range 0..2*PI
    while omega >= 2*PI do
        omega = omega - 2*PI
    end

    -- compute point value
    local is_electrode = (radius > 30 and radius < 35 and omega < 2)
    local voltage = 1

    -- set point value
    if is_electrode then pa:point(x, y, z, voltage, true) end
end

-- write file
pa:save("swirl.pa#")

print("done")


