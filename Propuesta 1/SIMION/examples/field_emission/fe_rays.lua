--[[
 fe_rays.lua - workbench user program for field emission example.

 See WARNINGS in the FLY2 file.
 
 2012-03-07,DM201203
--]]

simion.workbench_program()
local CAT = simion.import 'cathodelib.lua'

-- Variables passed to FLY2 file (see .fly2 file for details.
adjustable phi = 3
adjustable cathode_length = 2E-3
adjustable nsegments = 40
adjustable space = 1.5

-- Rescale field emission current by this factor (normally set to 1).
-- This is intended only for debugging purposes--e.g. to determine how much
-- current would need to be increased before space-charge effects set in.
adjustable rescale_current = 1


-- called on start of Fly'm...
function segment.flym()
  -- Regenerate particle definitions in case FE cathode properties changed.
  local var = { -- variables to pass to FLY2 file.
    phi=phi,
    cathode_length=cathode_length,
    nsegments=nsegments,
    space=space,
  }
  CAT.reload_fly2('fe_rays.fly2', var)
  
  -- In case the beam repulsion method will be used,
  -- update the beam method charge repulsion amount from FLY2 definitions.
  CAT.set_beam_repulsion_amount(var.total_current * rescale_current)

  print('rescale_current=', rescale_current)  
  print('total current (A)=', var.total_current * rescale_current)
    
  run() -- proceed with run
end


-- Optionally record currents on test plane.
-- You can alternately do this via Data Recording.
local TP = simion.import '../test_plane/testplanelib.lua'
local test1 = TP(0.65,0,0, 1,0,0, function()  -- x,y,z, ux,uy,uz
  print('x,y(mm), I(A)=', ion_px_mm, ion_py_mm, ion_cwf)
  -- note: one enhancement is to bin this and plot density
  mark()
end)
function segment.tstep_adjust()
  test1.tstep_adjust()
end
function segment.other_actions()
  test1.other_actions()
end

