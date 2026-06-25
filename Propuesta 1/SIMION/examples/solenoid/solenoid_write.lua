-- To use this, click "Run Lua Program" on the SIMION main screen.
-- The generated out.csv file can then be loaded into Excel.

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

local fh = assert(io.open("out.csv", "w"))

for x=0, 100, 10 do
  local bx,by,bz = field(x,0,0)
  fh:write(("%0.15f, %0.15f, %0.15f, %0.15f\n"):format(x, bx,by,bz))
end

fh:close()

print 'DONE writing the out.csv file.  You can view that file in Excel.'
