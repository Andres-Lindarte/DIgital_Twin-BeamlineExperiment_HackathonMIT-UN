--[[
 An experiment to test the effect of gravity on the beam.
 Typically this is very small (unless particles are massive).
--]]

simion.workbench_program()

-- Acceleration of gravity, mm/usec^2.
-- Note: this is approximate and varies over
-- location, http://en.wikipedia.org/wiki/Gravity_of_Earth .
local g = -9.81E-9

-- Add gravity acceleration to acceleration vector.
function segment.accel_adjust()
  ion_ay_mm = ion_ay_mm + g
end
