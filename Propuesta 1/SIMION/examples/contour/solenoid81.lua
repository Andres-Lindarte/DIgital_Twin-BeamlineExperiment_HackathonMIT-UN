--[[
  solenoid81.lua - SIMION workbench program that
  incorporates solenoid magnetic field from Biot-Savart
  calculation into workbench and plots magnetic field
  lines using contourlib81.lua.  This requires SIMION 8.1.
 
  See the the "solenoid" example for a more complete description
  concerning the solenoid field calculation itself.

 The workbench must contain an empty
 magnetic PA instance in which to apply this magnetic field.
 
 D.Manura, 2011-08
 (c) 2011 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

simion.workbench_program()

-- Load Biot-Savart magnetic field calculation support.
local MField = require "simionx.MField"

-- Defined solenoid magnetic field.
local field = MField.solenoid_hoops {
  current = 0.7958,
  first   = MField.vector(-100,0,0),
  last    = MField.vector(100,0,0),
  radius  = 25,
  nturns  = 10
}

-- Override magnetic field in magnetic PA instances
-- with that in the field object.
function segment.mfield_adjust()
  ion_bfieldx_gu, ion_bfieldy_gu, ion_bfieldz_gu =
    field(ion_px_mm, ion_py_mm, ion_pz_mm)
end

-- optionally draw solenoid wires too
field:draw()


-- Plot magnetic field lines. (requires SIMION 8.1)
local CON = simion.import 'contourlib81.lua'
CON.plot { func=field, z=0, npointsx=80, npointsy=20, vmax='percentile(99)', mark=true }
