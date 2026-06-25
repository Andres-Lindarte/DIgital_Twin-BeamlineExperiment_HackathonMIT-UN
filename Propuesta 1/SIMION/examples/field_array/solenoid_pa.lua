--[[
 solenoid_pa.lua - SIMION workbench program that incorporates
 magnetic field vectors represented in three PA files
 (one for each x,y,z component of the B-field).

 Note: the three PA objects were originally geneated by the
 makefile.lua batch mode program.

 D.Manura, 2011-03,2007-03
 (c) 2007-2012 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)
--]]

simion.workbench_program()

local CON = simion.import '../contour/contourlib81.lua'
local FL  = simion.import 'fieldlib.lua'

-- PA objects with x,y,z components of B-field.
local bxinst = simion.wb.instances[1]
local byinst = simion.wb.instances[2]
local bzinst = simion.wb.instances[3]

local bfield = FL.make_field(bxinst, byinst, bzinst)


CON.plot {func=bfield, mark=true, npoints=30, z=0}


-- (Optional) Just a check that field is consistent with theory.
do
  -- approx. 10 Gauss in +X direction in center of solenoid
  local bx,by,bz = bfield(0,0,0)
  assert(bx > 9 and bx < 11 and abs(by^2 + bz^2) < 1)
end

-- Override magnetic field in magnetic PA instances
-- with that in the field array.
function segment.mfield_adjust()
  ion_bfieldx_gu, ion_bfieldy_gu, ion_bfieldz_gu =
    bfield(ion_px_mm, ion_py_mm, ion_pz_mm)
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
