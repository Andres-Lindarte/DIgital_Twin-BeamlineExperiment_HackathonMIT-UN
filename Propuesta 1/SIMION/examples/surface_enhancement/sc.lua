--[[
 sc.lua - workbench user program for sc.iob.
 
 All this code is optional and used only to assist
 analysis.
 
 D.Manura, 2011-2012.
 (c) 2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()

-- Terminate particles upon reaching first quadrant a second time.
function segment.other_actions()
  if ion_time_of_flight > 0.02 and ion_px_mm > 0 and ion_py_mm > 0 then
    ion_splat = 1
  end
end

-- Theoretical potential at position (x,y,z),
-- used only for comparing against SIMION results.
local function phi_theo(x,y,z)
  local k = -200000
  local c = -2000
  local r = math.sqrt(x^2+y^2+z^2)
  return -k/r + c
end

function segment.initialize_run()
  -- Print PA potentials along radius (X=Y).
  print('r', 'phi_1', 'phi_2', 'phi_theo')
  for r=80,120,1 do
    local x,y,z = r*cos(math.pi/4), r*sin(math.pi/4), 0
    local phi_1 = simion.wb.instances[1] and simion.wb.instances[1].pa:potential_vc(x,y,z)
    local phi_2 = simion.wb.instances[2] and simion.wb.instances[2].pa:potential_vc(x,y,z)
    print(r, phi_1, phi_2, phi_theo(x,y,z))
  end
end

-- This is optional.  It allows executing the command
-- "make_difference()" from the SIMION command bar to subtract
-- theoretical potentials from PA's on the workbench,
-- to allow visualizing errors in the PE view.
-- WARNING: this makes the PA's unusable for flying, and
-- you should reload PA's from disk after using this.
function _G.make_difference()
  for i=1,#simion.wb.instances do
    local pa = simion.wb.instances[i].pa
    for x,y,z in pa:points() do
      local v,e = pa:point(x,y,z)
      v = e and 0 or v - phi_theo(x,y,z)
      pa:potential(x,y,z, v)
    end
  end
end


--[[
-- Uncomment this to override calculated E-field with a theoretical
-- E-field, for comparison.  Remaining errors will be due to the
-- trajectory calculation, which largely depends on T.Qual.
------
-- Theoretical E-field vector (Ex,Ey,Ez) V/mm at position (x,y,z) mm.
-- Used only for comparing against SIMION results.
local function e_theo(x,y,z)
  local k = -200000
  local r = math.sqrt(x^2+y^2+z^2)
  local rescale = (r == 0) and 0 or -k/r^3
  local Ex,Ey,Ez = rescale*x,rescale*y,rescale*z
  return Ex,Ey,Ez
end
function segment.efield_adjust()  -- force theoretical E-field
  local Ex,Ey,Ez = e_theo(ion_px_mm,ion_py_mm,ion_pz_mm)
  ion_dvoltsx_gu, ion_dvoltsy_gu, ion_dvoltsz_gu =  -Ex,-Ey,-Ez
end
--]]


--[[
-- Uncomment this is fill PA instance #2 with theoretical potentials
-- for comparison.  Remaining errors will be due to the interpolation of
-- potentials between PA grid points (as well as the trajectory calculation).
local inst = simion.wb.instances[2]
for xg,yg,zg in inst.pa:points() do
  if not inst.pa:electrode(xg,yg,zg) then
    local x,y,z = inst:pa_to_wb_coords(xg,yg,zg)
    inst.pa:potential(xg,yg,zg, phi_theo(x,y,z))
  end
end
--]]
