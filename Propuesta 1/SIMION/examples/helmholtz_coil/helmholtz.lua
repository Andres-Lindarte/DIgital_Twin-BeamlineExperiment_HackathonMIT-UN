--[[
 helmholtz.lua - SIMION workbench program that
 incorporates helmholtz coil magnetic field from Biot-Savart
 calculation into workbench.

 The workbench must contain an empty
 magnetic PA instance in which to apply this magnetic field.

 D.Manura, 2011-12-20, 2010-04
 (c) 2010-2011 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

simion.workbench_program()

-- Load Biot-Savart magnetic field calculation support.
local MField = require "simionx.MField"

local n = 1    -- number of turns
local I = 100  -- current (A) per turn
local R = 30   -- coil radius (mm)

-- Defined helmholtz coil magnetic field.
local field = MField.combined_field {
  -- two coaxial coils
  MField.hoop {
    current=n*I,
    center=MField.vector(0,0,-R/2),
    normal=MField.vector(0,0,1),
    radius=R
  },
  MField.hoop {
    current=n*I,
    center=MField.vector(0,0,R/2),
    normal=MField.vector(0,0,1),
    radius=R
  },

  -- optionally uncomment the below code for
  -- "three-axis Helmholtz coils" (six coils total).
  --[[
  MField.hoop {
    current=n*I,
    center=MField.vector(0,-R/2,0),
    normal=MField.vector(0,1,0),
    radius=R
  },
  MField.hoop {
    current=n*I,
    center=MField.vector(0,R/2,0),
    normal=MField.vector(0,1,0),
    radius=R
  },
  MField.hoop {
    current=n*I,
    center=MField.vector(-R/2,0,0),
    normal=MField.vector(1,0,0),
    radius=R
  },
  MField.hoop {
    current=n*I,
    center=MField.vector(R/2,0,0),
    normal=MField.vector(1,0,0),
    radius=R
  },
  --]]
}

-- Draw coils in SIMION 8.1
field:draw()

-- Print field along axis.
for z=-2*R,2*R,R/8 do
  local Bx, By, Bz = field(0,0,z)
  print(('z=\t%0.3e\tBz\t%0.5e'):format(z, Bz))
end

-- As a test, compare measured v.s. expected theoretical
-- field at coil center (0,0,0).
-- ( http://www.netdenizen.com/emagnet/helmholtz/idealhelmholtz.htm )
local mu_0 = 4 * math.pi -- Gauss mm/A
local B_theo = (4/5)^(3/2) * mu_0 * n * I / R
print("B_actual (gauss) = ", field(0,0,0))
print("B_theo   (gauss) = ", 0, 0, B_theo)

-- This part requires SIMION 8.1.
local CON = simion.import '../contour/contourlib81.lua'
if CON.can_draw then
  CON.plot{func=field, x=0,
           npoints=20, vmax='percentile(99)', mark=true}
end

-- Override magnetic field in magnetic PA instances.
function segment.mfield_adjust()
  ion_bfieldx_gu, ion_bfieldy_gu, ion_bfieldz_gu =
    field(ion_px_mm, ion_py_mm, ion_pz_mm)
end

print("note: prematurely terminates particles")
function segment.other_actions()
  if ion_time_of_flight > 0.03 then
    ion_splat = 1
  end
end

