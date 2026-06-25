--[[
 sector_2dc.lua - workbench user program for sector_2dc.iob.
--]]

simion.workbench_program()

-- deflection angle desired for magnet (degrees)
adjustable phi = 90

-- Gets angle (0..360 degrees) of current particle location
-- with respect to the center point of magnet's curvature.
local function phi_ion()
  return math.atan2(ion_py_mm, ion_pz_mm)*180/math.pi % 360
end

-- Artificially zero the B-field outside the angular range [0..phi].
function segment.mfield_adjust()
  if phi_ion() > phi then
    ion_bfieldx_gu, ion_bfieldy_gu, ion_bfieldz_gu = 0,0,0
  end
end


-- Merely to assist visualization, draw lines on effective
-- entrance and exit regions.
function segment.initialize_run()
  simion.experimental.plot_line_segment(0,0,0, 0,0,100)
  simion.experimental.plot_line_segment(0,0,0, 0,100*sin(rad(phi)),100*cos(rad(phi)))
end