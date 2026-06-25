-- SIMION Lua workbench user program for space-charge handling.
-- D.Manura, 2008-02.

simion.workbench_program()

-- Load particle-in-cell (PIC) code.
local PIC = simion.import('../piclib.lua')
PIC.load('charge')

adjustable PIC_refine_convergence = 1e-4
adjustable PIC_refine_period = 2
adjustable PIC_enable

-- Average Coulombs per particle.
-- ion_cwf units are C (3D and 2D cylindrical) or C/mm in z (2D planar).
adjustable C_per_particle =
  -0.73808E-6    -- current density (A mm^-2 = C sec^-1 mm^-2)
   * 0.02E-6     -- emission duration (sec), i.e. TOB range
   * math.pi*2^2 -- emission area (mm^2)
   / 1000        -- number of particles (unitless)


-- Called for each particle created inside an array.
PIC.is_init = false  -- used to verify that initialize is called
assert(not segment.initialize)
function segment.initialize()
  -- Compute relative weighting used to distribute charges in
  -- particles.
  --  
  -- Depending how your particles to be traced are defined, these
  -- particles may each represent a different relative quantity of
  -- real/physical particles.
  --
  -- If the field and particles both have 2D cylindrical symmetry and
  -- the particles are equidistantly spaced along a radius or diameter
  -- (e.g. pierce_pulse_2dcyl.fly2), then the charges assigned to the
  -- particles should be weighted proportionately to their distance
  -- from axis to represent the fact the each particle at radius r0
  -- represents particles that would actually exist over an entire
  -- circle having circumference 2*PI*r0.  WARNING: you would need to
  -- adjust r_mean if using a different beam size.
  --
  local r_mean = 1.0  -- half radius (mm)
  local r = sqrt(ion_py_mm^2 + ion_pz_mm^2) -- distance from axis.
  local weight = r / r_mean
  -- If the field and particles both have 2D cylindrical symmetry and
  -- the particles are (1) uniformly distributed over a 2D surface
  -- (e.g. pierce_pulse_2dcyl3d.fly2) or (2) non-equally spaced
  -- along a radius or diameter with density proportional to their
  -- distance from the axis, then the charges assigned to the
  -- particles should be equally weighted.
  --
  -- local weight = 1

  -- Assign charge to particle (used by PIC Poisson solving code).
  if PIC_enable ~= 0 then
    ion_cwf = C_per_particle * weight
  end

  PIC.is_init = true
end

