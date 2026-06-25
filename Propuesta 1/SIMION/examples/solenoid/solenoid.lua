-- solenoid.lua - SIMION workbench program that
-- incorporates solenoid magnetic field from Biot-Savart
-- calculation into workbench.
--
-- The workbench must contain an empty
-- magnetic PA instance in which to apply this magnetic field.
--
-- D.Manura, 2007-03
-- (c) 2007 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)

simion.workbench_program()

-- Load Biot-Savart magnetic field calculation support.
local MField = require "simionx.MField"

-- Defined solenoid magnetic field.
local field = MField.solenoid_hoops {
  current = 0.7958,
  first   = MField.vector(-50,0,0),
  last    = MField.vector(50,0,0),
  radius  = 10,
  nturns  = 100
}

-- Draw coils in SIMION 8.1
field:draw()

-- Optionally cache magnetic field calculations for improved speed.
-- WARNING: If you don't know what this code does, it's safer to just delete it.
-- See the README.html for details.
-- As written, this code does nothing.  To enable this code, change
-- "if false" to "if true".
if false then
  local FieldArray = require "simionx.FieldArray"
  local CachedField = require "simionx.CachedField"

  field = CachedField(field, FieldArray {
    symmetry = "cylindrical",
    nx = 401, ny = 41, nz = 1,
    scale = 0.5,
    x = -100
  })
end


-- Override magnetic field in magnetic PA instances
-- with that in the field object.
function segment.mfield_adjust()
  ion_bfieldx_gu, ion_bfieldy_gu, ion_bfieldz_gu =
    field(ion_px_mm, ion_py_mm, ion_pz_mm)
end

-- Called on every time-step.
function segment.other_actions()
  -- Just provide some visual effects here (optional).
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


-- Just some tests to check the field is as expected.
do
  local bx,by,bz = field(0,0,0)
  -- approx. 10 Gauss in +X direction in center of solenoid
  assert(bx > 9 and bx < 11 and abs(by^2 + bz^2) < 1)
end
