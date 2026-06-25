--
-- pa2text.lua
-- Reads the contents of a SIMION potential array file and writes the contents
-- to standard output.
--
-- This may be run from the command-line:
--
--   simion.exe --nogui lua pa2text.lua <file>
--
-- or simply from the "Run Lua Program" button on the SIMION main screen.
--
-- By default it loads the simple.pa# file if no PA file is specified.
--
-- D.Manura, Scientific Instrument Services, Inc.
--

assert(simion.pas, 'This example requires SIMION 8.1.')

local path = ... or 'simple.pa#'

local outpath = path .. ".txt"
local outfile = assert(io.open(outpath, "w"))

---- example reading
local pa = simion.pas:open(path)

-- print header parameters
outfile:write("begin_header\n")
local symmetry = pa.symmetry_type:gsub('^[23]d', '') -- simplify
outfile:write("symmetry=" .. symmetry .. "\n")
outfile:write("max_voltage=" .. pa.debug_max_voltage .. "\n")
outfile:write("nx=" .. pa.nx .. "\n")
outfile:write("ny=" .. pa.ny .. "\n")
outfile:write("nz=" .. pa.nz .. "\n")
outfile:write("mirror_x=" .. (pa.mirror_x and 1 or 0) .. "\n")
outfile:write("mirror_y=" .. (pa.mirror_y and 1 or 0) .. "\n")
outfile:write("mirror_z=" .. (pa.mirror_z and 1 or 0) .. "\n")
outfile:write("field=" .. pa.potential_type .. "\n")
outfile:write("ng=" .. (pa.ng or 100) .. "\n")
outfile:write("end_header\n")


outfile:write("begin_points\n")
for x,y,z in pa:points() do
   local potential, electrode = pa:point(x,y,z)
   local electrode_str = electrode and "1" or "0"
   outfile:write(electrode_str .. "," .. potential .. "\n")
end
outfile:write("end_points\n")

outfile:close()

print("finished writing ", outpath)





