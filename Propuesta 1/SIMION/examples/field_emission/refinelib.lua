--[[
 refinelib.lua - Utility functions relating to Refine.
 D.Manura,2012-03,2009
 (c) 2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

local REF = {}

--[[
 Regenerate PA instance object `painst` from GEM file
 with file name `gemfilename`.
 `var` may be a table that will be assigned to the global `_G.var`,
    which the GEM file can access.  It may be nil to omit it.
 `gemopt` are additional options to pass to the gem2pa command
    (defaults to '', meaning none).
  If PA instance is a .PA0 array on entry, then the file name extension
    will be changed to .PA# on exit.
--]]
function REF.update_painst_from_gem(painst, gemfilename, gemopt, var)
  gemopt = gemopt or ''
  local pafilename = painst.filename
  pafilename = pafilename:gsub('(%.[pP][a-zA-Z])[0-9]+$', '%1#')
        -- replace e.g. .pa0 with .pa#
  local ok, err = pcall(function()
    _G.var = var  -- set vars
    local cmd = 'gem2pa '..gemopt..' '..gemfilename..' '..pafilename
    print(cmd)
    simion.command(cmd)
    --TODO: use more direct API function for this.
  end)
  _G.var = nil -- clear (the pcall ensures this is always executed).
  if not ok then
    error(err)
  end
  painst.pa:load(pafilename)
  painst:_debug_update_size()
    -- update PA instance in case size changed (TODO: shouldn't be necessary)
  simion.redraw_screen()
end

--[[
 For points on boundary of PA instance `dpainst`,
 copy boundary conditions from PA instance `spainst`.
--]]
 function REF.copy_boundary(dpainst, spainst)
  local spa = spainst.pa
  local dpa = dpainst.pa
  local function copy(xgd,ygd,zgd)
    local x,y,z = dpainst:pa_to_wb_coords(xgd,ygd,zgd)
    local xgs,ygs,zgs = spainst:wb_to_pa_coords(x,y,z)
    if spa:inside_vc(xgs,ygs,zgs) then
      local v = spa:potential_vc(xgs,ygs,zgs)
      dpa:point(xgd,ygd,zgd, v, true)
    end
  end
  -- xmin
  if not dpa.mirror_x then
  for zg2=0,dpa.nz-1 do
  for yg2=0,dpa.ny-1 do
      copy(0,yg2,zg2)
  end end end
  -- xmax
  for zg2=0,dpa.nz-1 do
  for yg2=0,dpa.ny-1 do
    copy(dpa.nx-1,yg2,zg2)
  end end
  -- ymin
  if not dpa.mirror_y then
  for zg2=0,dpa.nz-1 do
  for xg2=0,dpa.nx-1 do
    copy(xg2,0,zg2)
  end end end
  -- ymax
  for zg2=0,dpa.nz-1 do
  for xg2=0,dpa.nx-1 do
    copy(xg2,dpa.ny-1,zg2)
  end end
  -- zmin
  if dpa.nz ~= 1 then
  if not dpa.mirror_z then
  for yg2=0,dpa.ny-1 do
  for xg2=0,dpa.nx-1 do
    copy(xg2,yg2,0)
  end end end end
  -- zmax
  if dpa.nz ~= 1 then
  for yg2=0,dpa.ny-1 do
  for xg2=0,dpa.nx-1 do
    copy(xg2,yg2,dpa.nz-1)
  end end end
end

return REF
