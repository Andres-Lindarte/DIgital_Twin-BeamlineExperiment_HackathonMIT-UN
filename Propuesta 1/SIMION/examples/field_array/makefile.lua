--[[
  makefile.lua
  Batch mode Lua program to generate solenoid.txt ASCII
  text file containing solenoid field data on a grid.

  D.Manura, 2012-03,2007-03.
  (c) 2007-2011 Scientific Instrument Services, Inc. (Licensed SIMION 8.0/8.1)
]]

local MField = require 'simionx.MField'
local FieldArray  = require 'simionx.FieldArray'

-- Define a magnetic field from a solenoid approximated
-- as a series of thin current hoops.
-- In an infinite solenoid, B = mu_0 * N * I, where mu_0 is the
-- magnetic field constant (4*pi*10^-7 Newtons per amps^2),
-- N is the number of turns per meter, and I is the amps.
-- The 0.7958 amps here corresponds to 1 Gauss if it were
-- an infinite solenoid (since it is non-infinite, it is
-- slightly less in the center).
local mfield =
  MField.solenoid_hoops {
    current = 0.7958,
    first = MField.vector(-50,0,0),
    last  = MField.vector(50,0,0),
    radius = 10,
    nturns = 100
  }


-- This is optional: Display progress.
if true then
  local mfield_old = mfield
  function mfield(x,y,z)
    local bx,by,bz = mfield_old(x,y,z)
    print(string.format("DEBUG, %g,%g,%g, %f,%f,%f", x,y,z, bx,by,bz))
    return bx,by,bz
  end
end

-- Build array for saving.
local array = FieldArray {
  symmetry = "cylindrical",
  nx = 101, ny = 11, nz = 1,
  potential_type = 'magnetic',
  scale = 2,
  x = -100
}
array:read(mfield)  -- Calculate field in array.

-- Save to text file (for solenoid.iob)
array:write("solenoid.csv")

-- Alternateley save as PA objects, which may be read more directly by SIMION
-- without the simionx.FieldArray library (for solenoid_pa.iob).
local bxpa, bypa, bzpa = array:convert_to_pas('solenoid-b', true)

print("done")
