--[[
 refinelib.lua - Utility functions relating to GEM.
 D.Manura,2012-03
 (c) 2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]


local GEM = {}

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
function GEM.update_painst_from_gem(painst, gemfilename, gemopt, var)
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

return GEM
