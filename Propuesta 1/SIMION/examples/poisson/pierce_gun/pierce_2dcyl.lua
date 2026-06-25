-- SIMION Lua workbench user program for space-charge handling.
-- D.Manura, 2011-12-07, 2008-02.

simion.workbench_program()

-- Load particle-in-cell (PIC) code.
local PIC = simion.import "../piclib.lua"

adjustable PIC_iterations = 4
adjustable PIC_refine_convergence = 1e-4
adjustable PIC_enable

-- Average A per particle.
-- ion_cwf units are A (3D and 2D cylindrical) or A/mm in z (2D planar).
adjustable A_per_particle =
  -0.73808E-6    -- (A mm^-2 = C sec^-1 mm^-2)
   * math.pi*2^2 -- (mm^2)
   / 20        -- number of particles (unitless)


function segment.initialize_run()
  print('A_per_particle=', A_per_particle)
end


-- Called for each particle created inside an array.
PIC.is_init = false  -- used to verify that initialize is called
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
  -- (e.g. pierce2dcylindrical.fly2), then the charges assigned to the
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
  -- (e.g. pierce2dcylindrical-3d.fly2) or (2) non-equally spaced
  -- along a radius or diameter with density proportional to their
  -- distance from the axis, then the charges assigned to the
  -- particles should be equally weighted.
  --
  -- local weight = 1

  -- Assign charge to particle (used by PIC Poisson solving code).
  if PIC_enable ~= 0 then
    ion_cwf = A_per_particle * weight
  end

  PIC.is_init = true
end

PIC.load('current')
