-- solenoid.lua - SIMION workbench program that
-- incorporates solenoid magnetic field from Biot-Savart
-- calculation into workbench and plots magnetic field
-- lines using contourlib.lua.
--
-- See the the "solenoid" example for a more complete description
-- concerning the solenoid field calculation itself.
--
-- The workbench must contain an empty
-- magnetic PA instance in which to apply this magnetic field.
--
-- D.Manura, 2008-03
-- (c) 2008 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)

simion.workbench_program()

-- Load Biot-Savart magnetic field calculation support.
local MField = require "simionx.MField"

-- Defined solenoid magnetic field.
local field = MField.solenoid_hoops {
  current = 0.7958,
  first   = MField.vector(-20,0,0),
  last    = MField.vector(20,0,0),
  radius  = 10,
  nturns  = 100
}


-- Override magnetic field in magnetic PA instances
-- with that in the field object.
function segment.mfield_adjust()
  ion_bfieldx_gu, ion_bfieldy_gu, ion_bfieldz_gu =
    field(ion_px_mm, ion_py_mm, ion_pz_mm)
end



-- Load code to plot magnetic field lines.
-- Note: In SIMION's particle definitions, you should define
-- particles that will trace the field lines.
simion.import 'contourlib.lua'
