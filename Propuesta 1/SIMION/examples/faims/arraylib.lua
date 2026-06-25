--[[
 arraylib.lua - represents arrays of T,P,v.
 
 Note: This file is provided for SIMION 8.0 compatibility.
 The preferred method of representing scalar and vector fields
 in SIMION 8.1 is to use regular PA files and access them with
 the Lua PA API (like in test3.lua).
 
 D.Manura 2011-11-12.
 (c) 2007-2011 Scientific Instrument Services, Inc. (SIMION 8.1/8.0 Licensed)
--]]

local AL = {}

local TF = simion.import 'textfilelib.lua'

-- Formatted print.
local function printf(...) print(string.format(...)) end


--[[
 Creates function for interpolating given array value at point
 (px,py,pz).
 Function is of the form
   array, px,py,pz -> value
  
 This is a helper function for load_array
--]]
local function make_array_interp(array)
  local xsize, ysize, zsize = array.xsize, array.ysize, array.zsize
  local nx, ny = array.nx, array.ny
  local is3d = array.symmetry == '3dplanar[xyz]'

  -- Compute array offsets.
  -- Array data starts on 4th element
  local add = 4
  local offset1 = add                -- [0,0,0]
  local offset2 = add + 1            -- [1,0,0]
  local offset3 = add +     array.nx -- [0,1,0]
  local offset4 = add + 1 + array.nx -- [1,1,0]
  local add = array.nx * array.ny
  local offset5 = offset1 + add      -- [0,0,1]
  local offset6 = offset2 + add      -- [1,0,1]
  local offset7 = offset3 + add      -- [0,1,1]
  local offset8 = offset4 + add      -- [1,1,1]

  return function(array, px,py,pz)
    -- keep inside bounds
    if px >= xsize then
      if px > xsize then error" ERROR: ion's x coord outside array" end
      px = px - 0.000001
    end
    if py >= ysize then
      if py > ysize then error" ERROR: ion's y coord outside array" end
      py = py - 0.000001
    end
    if is3d and pz >= zsize then
      if pz > zsize then error" ERROR: ion's z coord outside array" end
      pz = pz - 0.000001
    end

    -- Compute closest lower-left-corner (llc) array indices and
    -- fraction parts in 2D
    local ipx, fx1 = modf(px)
    local ipy, fy1 = modf(py)
    local fx0, fy0 = 1-fx1, 1-fy1
    local index = ipy * nx + ipx

    -- Compute point weightings.
    local w1 = fx0 * fy0   -- [0,0]
    local w2 = fx1 * fy0   -- [1,0]
    local w3 = fx0 * fy1   -- [0,1]
    local w4 = fx1 * fy1   -- [1,1]
    if is3d then
      -- Compute closest lower-left-corner (llc) array indices and
      -- fraction parts in 3D
      local ipz, fz1 = modf(pz)
      local fz0 = 1-fz1
      index = index + ipz * (ny*nx)

      local w5 = w1 * fz1  -- [0,0,1]
      local w6 = w2 * fz1  -- [1,0,1]
      local w7 = w3 * fz1  -- [0,1,1]
      local w8 = w4 * fz1  -- [1,1,1]
            w1 = w1 * fz0  -- [0,0,0]
            w2 = w2 * fz0  -- [1,0,0]
            w3 = w3 * fz0  -- [0,1,0]
            w4 = w4 * fz0  -- [1,1,0]
      return
        array[index + offset1] * w1 +
        array[index + offset2] * w2 +
        array[index + offset3] * w3 +
        array[index + offset4] * w4 +
        array[index + offset5] * w5 +
        array[index + offset6] * w6 +
        array[index + offset7] * w7 +
        array[index + offset8] * w8
    else -- 2D
      return
        array[index + offset1] * w1 +
        array[index + offset2] * w2 +
        array[index + offset3] * w3 +
        array[index + offset4] * w4
    end
  end
end


--[[
 Loads 2D or 3D array of data from text file with name filename.
 For example, this can be used as a pressure, temperature, or
 velocity map (to allow these parameters to vary as a function of
 position).
  
 The file must have the format as described in read_file_numbers and
 contain these values:
  
   nx,ny,nz -- first three file entries are array dimensions
             --   (number of points in x, y, and z directions)
    val      -- rest of array is linear list of values
    val      --   (suggest one per line), starting at
    val      --   x,y,z=0,0,0 and scanning in x, tehen by y, then by z
    ...
  
 Note that
  
   nx = 0    -- signifies an empty array (array is ignored)
   nz = 0    -- 2D cylindrical array
   nz = 1    -- 2D planar array
  
 The result is a table containing these fields:
  
   symmetry -- '2dplanar[xy]', '2dcylindrical[x]', or '3dplanar[xyz]'
   nx       -- number of points in x dimension
   ny       -- number of points in y dimension
   nz       -- number of points in z dimension
   xsize    -- x size (nx - 1)
   ysize    -- y size (ny - 1)
   zsize    -- z size (nz - 1)
  
 Returns nil if the file does not exist or array is empty.
--]]
function AL.load_array(filename)
  local array = TF.opt_read_file_numbers(filename)
  if array and array[1] == 0 then array = nil end

  if array then
    -- Get dimensions.
    local x_dim,y_dim,z_dim = array[1],array[2],array[3]
    printf("SDS Note: Loading array %s: nx=%d, ny=%d, nz=%d",
           filename, x_dim, y_dim, z_dim)
    array.nx = array[1]
    array.ny = array[2]
    array.nz = array[3]
    array.symmetry = (array.nz > 1) and '3dplanar[xyz]' or '2dplanar[xy]'
    if array.nx < 1 then error("X dimension invalid") end
    if array.ny < 1 then error("Y dimension invalid") end
    if array.nz == 0 then   -- cylindrical
      array.symmetry = '2dcylindrical'
      array.nz = 1
      print("SDS Note: 2D cylindrical arrays")
    end
    if array.nz < 1 then error("Z dimension invalid") end

    -- Compute limits and borders.
    array.xsize = abs(array.nx - 1)  -- max addressable x index (0 - nx-1)
    array.ysize = abs(array.ny - 1)  -- max addressable y index (0 - ny-1)
    array.zsize = abs(array.nz - 1)  -- max addressable z index (0 - nz-1)

    -- Allow object to be callable, returning interpolated values.
    setmetatable(array, {__call = make_array_interp(array)})
  end

  return array
end


--[[
 Given SIMION PA object `pa`, saves to file `filename` in text
 format loadable by `load_array`.
--]]
function AL.save_pa_as_text(filename, pa)
  local fh = assert(io.open(filename, 'w'))
  local nz = (pa.symmetry_type == '2dcylindrical') and 0 or pa.nz
  fh:write(pa.nx, ' ', pa.ny, ' ', nz, ' ; array dimensions\n')
  for x,y,z in pa:points() do
    fh:write(pa:potential(x,y,z), '\n')
  end
  fh:close()
end


--[[
 Given Lua array `array` (in form returned by `load_array`) converts
 to SIMION PA object and returns it.
--]]
function AL.luaarray_to_pa(array)
  local pa = simion.pas:open()
  pa:size(array.nx, array.ny, array.nz)
  pa.symmetry = array.symmetry
  for x,y,z in pa:points() do
    pa:potential(x,y,z, array(x,y,z))
  end
  return pa
end


--[[
 Converts array text file (in format compatible loadable by `load_array`)
 to PA file.  This is a convenience function.
 Example: AL.text_to_pa_file('p_defs.dat', 'tmp_p.pa')
--]]
function AL.text_to_pa_file(textpath, papath)
  local array = AL.load_array(textpath)
  local pa = AL.luaarray_to_pa(array)
  pa:save(papath)
  pa:close()
end


return AL
