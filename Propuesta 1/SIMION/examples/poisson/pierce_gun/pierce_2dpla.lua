-- SIMION Lua workbench user program for space-charge handling.
-- D.Manura, 2011-12-07, 2008-02.

simion.workbench_program()

-- Load particle-in-cell (PIC) code.
local PIC = simion.import "../piclib.lua"

adjustable PIC_iterations = 4
adjustable PIC_refine_convergence = 1e-4
adjustable PIC_enable

-- Average A per mm in z per particle.
-- ion_cwf units are A (3D and 2D cylindrical) or A/mm in z (2D planar).
adjustable A_per_mm_per_particle =
  -0.73808E-6    -- (A mm^-2 = C sec^-1 mm^-2)
   * 2           -- (mm)
   / 20         -- number of particles (unitless)


function segment.initialize_run()
  print('A_per_mm_per_particle=', A_per_mm_per_particle)
end


-- Called for each particle created inside an array.
PIC.is_init = false  -- used to verify that initialize is called
function segment.initialize()
  -- Note: unlike in pierce2dcylindrical.lua (cylindrical symmetry),
  -- there is unlikely any relative charge weighting to apply here.

  -- Assign charge to particle (used by PIC Poisson solving code).
  if PIC_enable ~= 0 then
    ion_cwf = A_per_mm_per_particle
  end

  PIC.is_init = true
end

PIC.load('current')
