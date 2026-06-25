simion.workbench_program()

adjustable bx = 15 -- Gauss
adjustable by = 0  -- Gauss
adjustable bz = 0  -- Gauss

function segment.mfield_adjust()
  ion_bfieldx_gu = bx
  ion_bfieldy_gu = by
  ion_bfieldz_gu = bz
end
