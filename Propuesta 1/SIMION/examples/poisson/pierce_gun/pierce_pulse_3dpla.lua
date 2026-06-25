-- SIMION Lua workbench user program for space-charge handling.
-- D.Manura, 2008-02.

simion.workbench_program()

-- Load particle-in-cell (PIC) code.
local PIC = simion.import "../piclib.lua"
PIC.load('charge')

adjustable PIC_refine_convergence = 1e-4
adjustable PIC_refine_period = 2
adjustable PIC_enable

-- Average Coulombs per particle.
-- ion_cwf units are C (3D and 2D cylindrical) or C/mm in z (2D planar).
adjustable C_per_particle =
  -0.73808E-6    -- current density (A mm^-2 = C sec^-1 mm^-2)
   * 0.02E-6     -- emission duration (sec), i.e. TOB range
   * 2^2         -- emission area (mm^2)
   / 20000       -- number of particles (unitless)


function segment.initialize_run()
  print('C_per_particle=', C_per_particle)
end


-- Called for each particle created inside an array.
PIC.is_init = false  -- used to verify that initialize is called
assert(not segment.initialize)
function segment.initialize()
  -- Assign charge to particle (used by PIC Poisson solving code).
  if PIC_enable ~= 0 then
    ion_cwf = C_per_particle
  end

  PIC.is_init = true
end
