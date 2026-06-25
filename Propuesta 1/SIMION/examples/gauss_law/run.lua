-- run.lua - Lua batch mode program for analyze fields
-- (total charge and field energy) for computing charge/capacitance.
--
-- Calculates charge and capacitance from fields defined
-- in a SIMION array or an analytic field.
--
-- D.Manura-2007-08/2011
-- (c) 2007-2011 Scientific Instrument Services, Inc.
-- Licensed under the terms of SIMION 8.1


assert(simion.pas, 'This example requires SIMION 8.1.')


local FAN = require 'simionx.FieldAnalysis'
local sqrt = math.sqrt

-- Build and refine PAs from GEMs (if they don't exist).
local function exists_file(filename) -- test if file exists
  local f = io.open(filename)
  local exists = false
  if f then f:close(); exists = true end
  return exists  
end
local function build(name) -- create+refine a PA
  local gemname = name .. '.gem'
  local paname  = name .. '.pa'
  if not exists_file(paname) then
    simion.command('gem2pa ' .. gemname .. ' ' .. paname)
    simion.command('refine ' .. paname)
  end
end
build 'sc3d'
build 'sc2d'
build 'sc2d10'

-- Define a theoretical field for spherical capacitor
-- with R1=80 mm, R2=120 mm, V1=500, V2=-1000/3.
local function field(x,y,z)
  local r = sqrt(x*x+y*y+z*z)
  local er = 200000/(r*r)
  local f = er/r
  if r > 120 or r < 80 then return 0,0,0 end
  return x*f, y*f, z*f
end

print "\n";


-- pa_name: SIMION potential array (PA) file name
-- L: mm/gu scaling factor
--local pa_name,L = 'sc3d.pa',1
--local pa_name,L = 'sc2d.pa',1
local pa_name,L = 'sc2d10.pa',0.1

-- load potential array
simion.pas:close()
local pa = assert(simion.pas:open(pa_name))
local ndimensions = (pa.nz > 1) and 3 or 2 -- number of dimensions


-- Run tests.


print "\n\nTest 1: field energy inside sphere (using theoretical field)."
local EXPECTED = 9.272084E-6
print("Expecting", EXPECTED)
FAN.field_energy_display {
  field = field,
  shape = FAN.sphere_filled(0,0,0, 125),
  mm_per_unit=1,
  min_iterations=0.1*125^3,
  rel_err=0.0005
}


print "\n\nTest 2: field energy inside 3D box (using theoretical field)."
local EXPECTED = 9.272084E-6
print("Expecting", EXPECTED)
FAN.field_energy_display {
  field = field,
  shape = FAN.box_filled(-125,-125,-125, 125,125,125),
  mm_per_unit=1,
  min_iterations=0.1*125^3,
  rel_err=0.0005
}


print "\n\nTest 3: field energy inside sphere."
local EXPECTED = 9.272084E-6
print("Expecting", EXPECTED)
FAN.field_energy_display {
  field=pa,
  shape=FAN.sphere_filled(0/L,0/L,0/L, 125/L),
  mm_per_unit=L,
  min_iterations=0.1*(125/L)^ndimensions,
  rel_err=0.0005
}


print "\n\nTest 4: charge inside sphere via field energy calculation."
local EXPECTED = 2.225301E-8
print("Expecting", EXPECTED)
FAN.charge_from_field_energy_display {
  field=pa,
  shape=FAN.sphere_filled(0/L,0/L,0/L, 125/L),
  mm_per_unit=L,
  potential=833.33333,
  min_iterations=0.1*(125/L)^ndimensions,
  rel_err=0.0005
}


print "\n\nTest 5: charge inside 3D box via field energy calculation."
local EXPECTED = 2.225301E-8
print("Expecting", EXPECTED)
local result = FAN.charge_from_field_energy_display {
  field=function(x,y,z)  -- avoid accessing points outside the PA
          local rsquare = y*y+z*z
          if rsquare > 125*125/L/L
          then return 0,0,0 -- no field outside
          else return pa:field_vc(x,y,z) end
        end,
  shape=FAN.box_filled(-125/L,-125/L,-125/L, 125/L,125/L,125/L),
  mm_per_unit=L,
  potential=833.33333,
  min_iterations=0.1*(125/L)^ndimensions,
  rel_err=0.0005
}


print "\n\nTest 6: charge inside sphere via Gauss's Law calculation."
local EXPECTED = 2.225301E-8
print("Expecting", EXPECTED)
local result = FAN.charge_from_gauss_law_display {
  field=pa,
  shape=FAN.sphere(0/L,0/L,0/L, 100/L),
  mm_per_unit=L,
  min_iterations=0.1*(125/L)^ndimensions,
  rel_err=0.0005
}


print "\n\nTest 7: charge inside 3D box via Gauss's Law calculation (less accurate)."
local EXPECTED = 2.225301E-8
print("Expecting", EXPECTED)
local result = FAN.charge_from_gauss_law_display {
  field=pa,
  shape=FAN.box(-82/L,-82/L,-82/L, 82/L,82/L,82/L), 
  mm_per_unit=L,
  min_iterations=0.1*(125/L)^ndimensions,
  rel_err=0.0005
}


print "\n\ndone"


