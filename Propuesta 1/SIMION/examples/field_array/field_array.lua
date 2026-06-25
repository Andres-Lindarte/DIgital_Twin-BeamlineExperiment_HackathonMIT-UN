-- field_array.lua - SIMION workbench program that incorporates
-- magnetic field from data file into workbench.
--
-- The workbench must contain an empty magnetic PA instance
-- in which to apply this magnetic field.
--
-- Note: the data file solenoid.csv was originally generated
-- from the makefile.lua batch mode program.
--
-- D.Manura, 2007-03
-- (c) 2007 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)

simion.workbench_program()

-- Load field interpolation support.
local FieldArray = require "simionx.FieldArray"

-- Load solenoid field from data file.
local field = FieldArray("solenoid.csv")

-- (Optional) Just a check that field is consistent with theory.
do
  -- approx. 10 Gauss in +X direction in center of solenoid
  local bx,by,bz = field:get(0,0,0)
  assert(bx > 9 and bx < 11 and abs(by^2 + bz^2) < 1)
end

-- Override magnetic field in magnetic PA instances
-- with that in the field array.
function segment.mfield_adjust()
  ion_bfieldx_gu, ion_bfieldy_gu, ion_bfieldz_gu =
    field:get(ion_px_mm, ion_py_mm, ion_pz_mm)
end

-- Called on every time-step.
function segment.other_actions()
  -- (Optional) Provide some visual effects here.
  -- Things like this can assist in understanding.

  -- magnitude of field
  local bm = sqrt(ion_bfieldx_mm^2 + ion_bfieldy_mm^2 + ion_bfieldz_mm^2)
  if bm > 9 then
    ion_color = 2  -- green
  else
    ion_color = 1  -- red
  end
  if bm == 0 then  -- outside of field
    mark()
  end
end
