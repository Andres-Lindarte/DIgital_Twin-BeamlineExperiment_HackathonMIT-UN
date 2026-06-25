simion.workbench_program()

-- Earth's bfield in Gauss.
-- Note: this is approximate and varies in direction
-- and location, 0.25–0.65 gauss.
-- http://en.wikipedia.org/wiki/Earth%27s_magnetic_field .
local b = 0.5

-- Add B-field.
function segment.mfield_adjust()
  ion_bfieldz_gu = b
  -- or alternately in x or y direction...
end
