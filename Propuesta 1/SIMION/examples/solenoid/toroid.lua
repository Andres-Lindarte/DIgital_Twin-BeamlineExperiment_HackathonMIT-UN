-- toroid.lua - SIMION workbench program that
-- incorporates toroidal magnetic field from Biot-Savart
-- calculation into workbench.
--
-- The workbench must contain an empty
-- magnetic PA instance in which to apply this magnetic field.
--
-- D.Manura, 2011-10
-- (c) 2011 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0/8.1)

simion.workbench_program()

-- Load Biot-Savart magnetic field calculation support.
local MField = require "simionx.MField"

-- Defined solenoid magnetic field.
local t = {}
for i=0,360,5 do
  table.insert(t, MField.hoop {
    current = 20,
    center  = MField.vector(40*math.cos(i*math.pi/180), 40*math.sin(i*math.pi/180), 0),
    normal  = MField.vector(-1*math.sin(i*math.pi/180),    math.cos(i*math.pi/180), 0),
    radius  = 10
  })
end
local field = MField.combined_field(t)

-- This part requires SIMION 8.1.
if field.draw then
  -- Draw coils and plot field vectors.
  field:draw()
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot{func=field, xl=-50, xr=50, yl=-50, yr=50, z=0, npoints=40, color=3, vmax='percentile(99)'}
end

-- Override magnetic field in magnetic PA instances
-- with that in the field object.
function segment.mfield_adjust()
  ion_bfieldx_gu, ion_bfieldy_gu, ion_bfieldz_gu = field(ion_px_mm, ion_py_mm, ion_pz_mm)
end
