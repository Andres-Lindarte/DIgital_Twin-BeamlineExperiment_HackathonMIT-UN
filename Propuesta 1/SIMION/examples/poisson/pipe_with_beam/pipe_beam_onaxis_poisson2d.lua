simion.workbench_program()

-- Load particle-in-cell (PIC) code.
local PIC = simion.import "../piclib.lua"
PIC.load('current')

-- options in piclib.
adjustable PIC_iterations = 3
adjustable PIC_refine_convergence = 1e-5

PIC.add_charge_array(1)


-- Average A per particle.
-- ion_cwf units are A (3D and 2D cylindrical) or A/mm in z (2D planar).
adjustable A_per_particle =
  -0.2E-3  -- A
   / 100         -- number of particles (unitless)


-- Called for each particle created inside an array.
PIC.is_init = false  -- used to verify that initialize is called
function segment.initialize()
  PIC.segment.initialize()
  -- Note: unlike in pierce2dcylindrical.lua (cylindrical symmetry),
  -- there is unlikely any relative charge weighting to apply here.

  -- Assign charge to particle (used by PIC Poisson solving code).
  if PIC_enable ~= 0 then
    ion_cwf = A_per_particle
  end

  PIC.is_init = true
end

-- Optionally plot charge density.
function segment.terminate_run()
  PIC.segment.terminate_run()
  local CL = simion.import'../../contour/contourlib81.lua'
  CL.plot{func=PIC.charge_density,z=0,v0='maximum',v1='minimum'} 
end
