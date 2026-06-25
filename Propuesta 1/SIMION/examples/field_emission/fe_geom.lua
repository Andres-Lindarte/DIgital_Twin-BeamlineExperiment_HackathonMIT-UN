--[[
 fe_geom.lua - Example to allow easy adjustment of field
 emission geometric parameters from adjustable variables,
 as well a trasfering boundary conditions between
 coarse and fine PAs.
 D.Manura, 2012-10-08,2012-03-07
 (c) 2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1).
--]]

simion.workbench_program()
local REF = simion.import 'refinelib.lua'

-- Geometric parameters (see fe_geom.gem).
adjustable tip_radius = 1  -- micrometer (um)
adjustable cone_angle = 10 -- degrees
adjustable suppressor_radius = 50  -- um
adjustable extractor_radius = 70  -- um
adjustable mmgu = 0.0001 -- mm/gu
adjustable convergence = 1  -- V  (reduce this for higher accuracy)

-- Parameters for optional fine PA.
adjustable fine_mmgu = 0.00001  -- PA grid unit size, mm/gu

--[[
 Prints contents of parameters in current geometry.
 This might differ from adjustable variables if regenerate()
 has not been called.
--]]
local function print_geometry()
  local file = io.open('fe_geom_params.txt', 'r')
  if file then
    print(file:read'*a')
    file:close()
  end
end

--[[
 Recreates the geometry based on adjustable variables.
 regenerate(false) will regenerate without refining.
 This command can be run by entering "regenerate()" in the SIMION command bar.
--]]
function _G.regenerate(refine)
  if refine == nil then refine = true end

  -- Regenerate PA from GEM.
  REF.update_painst_from_gem(simion.wb.instances[1], 'fe_geom.gem', '', {
    tip_radius = tip_radius,
    cone_angle = cone_angle,
    suppressor_radius = suppressor_radius,
    extractor_radius = extractor_radius,
    mmgu = mmgu,
  })
  print_geometry()
  -- Note: if you don't need to fast adjust voltages, then a basic PA
  -- (.pa rather than .pa#) would be more efficient here.

  -- Refine.
  if refine then
    local pa = simion.wb.instances[1].pa
    pa:refine { convergence=convergence }
    -- TODO: preserve original fast adjust electrode potentials as well.
    pa:fast_adjust {[3]=10000}
    simion.redraw_screen()
  end
  
  print 'done regeneration'
end


--[[
 Regenerates the fine PA.
 This should only be done after regenerating the coarse PA ("regenerate()").
 This command can be run by entering "regenerate_fine()" in the SIMION command bar.
--]]
function _G.regenerate_fine(refine)
  if refine == nil then refine = true end

  -- Get instances and PA's.
  local painst1 = simion.wb.instances[1]
  local painst2 = simion.wb.instances[2]
  local pa2 = painst2.pa
  
  -- Shift into position.
  painst2.ox = 0.05  -- xsize/2

  -- Get offset of coarse PA with respect to fine PA, in fine PA grid units. 
  local xshift, yshift, zshift = painst2:wb_to_pa_coords(painst1:pa_to_wb_coords(0,0,0))
  
  -- Regenerate PA from GEM..
  REF.update_painst_from_gem(painst2, 'fe_geom.gem',
    '--x='..xshift..' --y='..yshift..' --z='..zshift,
    {
    tip_radius = tip_radius,
    cone_angle = cone_angle,
    suppressor_radius = suppressor_radius,
    extractor_radius = extractor_radius,
    -- override some variables
    mmgu=fine_mmgu,
    xsize=0.1,
    ysize=0.03,
  })
   
  -- Since the fine PA is a basic PA,
  -- replace electrode numbers with actual voltages.
  print 'replacing points...'
  for x,y,z in pa2:points() do
    local v = pa2:potential(x,y,z)
    if v == 1 then pa2:potential(x,y,z, 0) end
  end
  
  -- For boundary points of fine PA, copy boundary conditions
  -- from coarse PA.
  REF.copy_boundary(painst2, simion.wb.instances[1])

  -- Refine PA.
  if refine then
    pa2:refine{convergence=convergence}
    simion.redraw_screen()
  end
  
  print 'done regeneration'
end

--[[
 Makes workbench size tighter.
 Note: currently the "Min" button on the Workbench tab rounds
 workbench size to nearest 1 mm, which may not be a tight fit.
 Command can be run by entering "fix_workbench_size()" in SIMION command bar.
--]]
function _G.fix_workbench_size()
  simion.wb.bounds.yr =  0.3
  simion.wb.bounds.yl = -0.3
  simion.wb.bounds.zr =  0.3
  simion.wb.bounds.zl = -0.3
  simion.wb.bounds.xl = -0.2
end

print_geometry()
